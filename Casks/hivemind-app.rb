cask "hivemind-app" do
  version "0.6.8"
  sha256 arm: "dbfa9402c49c74a0d3ba0c6d94f85a62902dff97c07ee44187dca576745706d3"

  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v#{version}/hivemind-darwin-arm64"
  name "Hivemind"
  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://hivemind.wandb.tools"

  # Daemon self-updates; brew upgrade is a no-op without --greedy.
  auto_updates true

  # Same manifest as the upgrade watcher reads.
  livecheck do
    url "https://raw.githubusercontent.com/wandb/homebrew-taps/main/manifests/hivemind-latest.json"
    strategy :json do |json|
      json["version"]
    end
  end

  depends_on arch: :arm64
  depends_on macos: ">= :big_sur"

  # Both casks write /opt/homebrew/bin/hivemind, so they cannot coexist.
  conflicts_with cask: "wandb/taps/hivemind-app-prerelease"

  binary "hivemind-darwin-arm64", target: "hivemind"

  postflight do
    plist_path        = File.expand_path("~/Library/LaunchAgents/com.wandb.hivemind.plist")
    system_plist_path = "/Library/LaunchAgents/com.wandb.hivemind.plist"
    pkg_binary_path   = "/usr/local/hivemind/bin/hivemind"
    log_dir           = File.expand_path("~/Library/Logs/hivemind")
    uid               = Process.uid

    # The managed-pkg system plist takes the com.wandb.hivemind launchd
    # label at every GUI login (system LaunchAgents load before user
    # ones). Touching the label here would knock the pkg daemon offline
    # until next reboot, and the user plist we'd write would never get
    # to load anyway. Install the cask binary + symlink only and skip
    # the LaunchAgent dance — but only if the pkg is *actually*
    # installed; a stale system plist alone (debris from a botched
    # uninstall) shouldn't stop us from setting up our own daemon.
    if File.exist?(system_plist_path) && File.exist?(pkg_binary_path)
      ohai "Managed Hivemind pkg detected at #{pkg_binary_path}; "\
           "leaving the system LaunchAgent in charge."
    else
      FileUtils.mkdir_p(File.dirname(plist_path))
      FileUtils.mkdir_p(log_dir)

      File.write(plist_path, <<~PLIST)
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.wandb.hivemind</string>
            <key>ProgramArguments</key>
            <array>
                <string>#{HOMEBREW_PREFIX}/bin/hivemind</string>
                <string>run</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>#{log_dir}/hivemind.out.log</string>
            <key>StandardErrorPath</key>
            <string>#{log_dir}/hivemind.err.log</string>
        </dict>
        </plist>
      PLIST

      # Stale /tmp logs confuse `hivemind status`'s most-recent-file heuristic.
      ["/tmp/hivemind.log", "/tmp/hivemind.err"].each { |f| File.delete(f) if File.exist?(f) }

      # Bootout first so an upgrade doesn't fail with "already loaded".
      system_command "/bin/launchctl",
                     args: ["bootout", "gui/#{uid}", plist_path],
                     print_stderr: false,
                     must_succeed: false
      system_command "/bin/launchctl",
                     args: ["bootstrap", "gui/#{uid}", plist_path],
                     must_succeed: false
      system_command "/bin/launchctl",
                     args: ["enable", "gui/#{uid}/com.wandb.hivemind"],
                     must_succeed: false
    end

    # Canonical CLI path: ~/.local/bin/hivemind → brew bin (stable
    # across cask version bumps, unlike the Caskroom path). Always
    # write this — the cask binary is still useful even when the pkg
    # daemon is the active supervisor.
    user_bin = Pathname.new(File.expand_path("~/.local/bin"))
    user_bin.mkpath
    user_bin_hivemind = user_bin / "hivemind"
    user_bin_hivemind.unlink if user_bin_hivemind.symlink? || user_bin_hivemind.exist?
    user_bin_hivemind.make_symlink(Pathname.new("#{HOMEBREW_PREFIX}/bin/hivemind"))
  end

  # Only bootout/delete the plist if it still points at this cask's
  # binary; another channel (pkg/script/uv-tool) may have taken over
  # since install (last-writer-wins on ~/Library/LaunchAgents). Also
  # skip when the managed-pkg system plist owns the label — bootout
  # by service target would tear down the pkg's daemon, which the
  # user did not ask us to touch.
  uninstall_preflight do
    plist_path        = File.expand_path("~/Library/LaunchAgents/com.wandb.hivemind.plist")
    system_plist_path = "/Library/LaunchAgents/com.wandb.hivemind.plist"
    pkg_binary_path   = "/usr/local/hivemind/bin/hivemind"
    pkg_active        = File.exist?(system_plist_path) && File.exist?(pkg_binary_path)
    if File.exist?(plist_path) &&
       File.read(plist_path).include?("#{HOMEBREW_PREFIX}/bin/hivemind") &&
       !pkg_active
      uid = Process.uid
      system_command "/bin/launchctl",
                     args: ["bootout", "gui/#{uid}/com.wandb.hivemind"],
                     print_stderr: false,
                     must_succeed: false
      File.delete(plist_path)
    end
  end

  uninstall_postflight do
    user_bin_hivemind = Pathname.new(File.expand_path("~/.local/bin/hivemind"))
    if user_bin_hivemind.symlink?
      target = File.readlink(user_bin_hivemind.to_s)
      if target.include?("Caskroom/hivemind-app") || target == "#{HOMEBREW_PREFIX}/bin/hivemind"
        user_bin_hivemind.unlink
      end
    end
  end

  zap trash: [
    "~/.hivemind",
    "~/Library/Logs/hivemind",
    "/tmp/hivemind.log",
    "/tmp/hivemind.err",
  ]

  caveats <<~EOS
    Hivemind is running as a per-user LaunchAgent (com.wandb.hivemind).
    Manage it with:

        hivemind status
        hivemind restart
        hivemind doctor

    This cask self-updates: the daemon polls for new signed releases and
    replaces its own binary in the Caskroom. `brew upgrade` is a no-op
    for this cask — pass --greedy to force a reinstall.
  EOS
end
