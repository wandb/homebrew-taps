cask "hivemind-app-prerelease" do
  version "0.0.1-test1"
  sha256 arm: "ca043f5468651628ea000b13bd163816d480dcfda448147c19121267694774bc"

  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v#{version}/hivemind-darwin-arm64"
  name "Hivemind (pre-release)"
  desc "Pre-release builds of the hivemind daemon — for testing only"
  homepage "https://hivemind.wandb.tools"

  # Auto-updates: same as the stable cask, the daemon polls and replaces
  # itself in place. Pre-release manifests live at
  # https://raw.githubusercontent.com/wandb/homebrew-taps/main/manifests/hivemind-prerelease.json
  # — set HIVEMIND_UPGRADE_MANIFEST_URL to that URL in the LaunchAgent
  # plist if you want the watcher to pull pre-releases instead of stable.
  auto_updates true

  depends_on arch: :arm64
  depends_on macos: ">= :big_sur"

  # Same coexistence policy as the stable cask: this cask cannot be
  # installed alongside hivemind-app because both write the symlink
  # /opt/homebrew/bin/hivemind. Brew refuses up front. Switch channels
  # by uninstalling the other one first:
  #
  #     brew uninstall --cask wandb/taps/hivemind-app           # (or -prerelease)
  #     brew install   --cask wandb/taps/hivemind-app-prerelease
  #
  # ~/.hivemind/ (credentials, state, telemetry) is preserved across
  # the switch.
  preflight do
    legacy_system_plist = "/Library/LaunchAgents/com.wandb.hivemind.plist"
    if File.exist?(legacy_system_plist)
      odie <<~EOS
        Detected a legacy system-wide LaunchAgent from an older .pkg install:

            #{legacy_system_plist}

        This file is root-owned and must be removed with sudo before
        the cask can take over. Run:

            sudo /usr/local/hivemind/uninstall.sh

        Your credentials and state in ~/.hivemind/ will be preserved.
        Then retry:

            brew install --cask wandb/taps/hivemind-app-prerelease
      EOS
    end
  end

  # Same binary name as the stable cask so commands work the same way
  # (`hivemind doctor`, `hivemind status`, etc.). The cask name suffix
  # only affects Homebrew's tracking, not what's on $PATH.
  binary "hivemind-darwin-arm64", target: "hivemind"

  postflight do
    plist_path = File.expand_path("~/Library/LaunchAgents/com.wandb.hivemind.plist")
    FileUtils.mkdir_p(File.dirname(plist_path))

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
          <string>/tmp/hivemind.log</string>
          <key>StandardErrorPath</key>
          <string>/tmp/hivemind.err</string>
      </dict>
      </plist>
    PLIST

    uid = Process.uid
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

  uninstall launchctl: "com.wandb.hivemind",
            delete:    "~/Library/LaunchAgents/com.wandb.hivemind.plist"

  zap trash: [
    "~/.hivemind",
    "~/Library/Logs/hivemind.log",
    "~/Library/Logs/hivemind.err",
    "/tmp/hivemind.log",
    "/tmp/hivemind.err",
  ]

  caveats <<~EOS
    Hivemind PRE-RELEASE is running as a per-user LaunchAgent
    (com.wandb.hivemind). This is an unstable build — please report
    issues to https://github.com/wandb/agentstream/issues with the
    `hivemind doctor` output attached.

    Manage the daemon with:

        hivemind status
        hivemind restart
        hivemind doctor

    To follow the pre-release manifest for auto-upgrades, add this to
    ~/Library/LaunchAgents/com.wandb.hivemind.plist (under
    EnvironmentVariables) and reload the agent:

        HIVEMIND_UPGRADE_MANIFEST_URL=https://raw.githubusercontent.com/wandb/homebrew-taps/main/manifests/hivemind-prerelease.json
        HIVEMIND_UPGRADE_APPLY_ENABLED=1

    To switch back to the stable channel:

        brew uninstall --cask wandb/taps/hivemind-app-prerelease
        brew install   --cask wandb/taps/hivemind-app

    Your credentials in ~/.hivemind/ are preserved across the switch.
  EOS
end
