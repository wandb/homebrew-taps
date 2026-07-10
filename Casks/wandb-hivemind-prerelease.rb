cask "wandb-hivemind-prerelease" do
  version "1.0.4rc2"
  sha256 arm: "9af5f63c97c4c0782d5bb951b3ed456182527d04a90aadbe8867f039d3f48497"

  url "https://github.com/wandb/hivemind/releases/download/v#{version}/hivemind-darwin-arm64",
      verified: "github.com/wandb/hivemind/"
  name "W&B HiveMind (pre-release)"
  desc "Pre-release builds of the HiveMind daemon — for testing only"
  homepage "https://hivemind.wandb.tools/"

  # Same manifest the daemon's upgrade watcher polls on the prerelease
  # channel.
  livecheck do
    url "https://raw.githubusercontent.com/wandb/hivemind/main/manifests/hivemind-prerelease.json"
    strategy :json do |json|
      json["version"]
    end
  end

  # The daemon self-updates in place; `brew upgrade` is a no-op for this
  # cask unless --greedy is passed. Both casks install the same
  # `hivemind` binary, hence the conflict; switch channels by
  # uninstalling the other cask first (~/.hivemind is preserved).
  # Cask conflicts_with only accepts cask: — formula collisions
  # (homebrew-core's hivemind, the legacy wandb/taps/hivemind formula)
  # surface as a binary-link error at install time.
  auto_updates true
  conflicts_with cask: "wandb/taps/wandb-hivemind"
  depends_on arch: :arm64
  depends_on macos: :sonoma

  binary "hivemind-darwin-arm64", target: "hivemind"

  postflight do
    # Marker pins the upgrade watcher to the prerelease manifest.
    # Without it, the daemon would silently slide back to stable on the
    # next stable release.
    config_dir = "#{File.expand_path(ENV.fetch("XDG_CONFIG_HOME", "~/.config"))}/hivemind"
    FileUtils.mkdir_p(config_dir)
    File.write("#{config_dir}/install-method", <<~MARKER)
      # Written by wandb-hivemind-prerelease cask postflight.
      method = "brew-cask"
      channel = "prerelease"
      installed_at = "#{Time.now.utc.iso8601}"
    MARKER

    # The Nuitka onefile binary extracts ~180 MB to ~/.cache on its
    # first execution — several seconds of I/O better paid here than on
    # the user's first command. Best-effort: never fail the install
    # over it (e.g. offline Gatekeeper assessment).
    system_command staged_path/"hivemind-darwin-arm64",
                   args:         ["--version"],
                   must_succeed: false,
                   print_stdout: false,
                   print_stderr: false
  end

  # `hivemind start` registers this label; remove it with the binary so
  # launchd doesn't KeepAlive-respawn a deleted executable.
  uninstall launchctl: "com.wandb.hivemind"

  # ~/.hivemind (credentials + sync state) is intentionally not zapped:
  # it is shared by the other install channels (pkg, script, uv tool).
  zap trash: [
    "~/.config/hivemind/install-method",
    "~/Library/LaunchAgents/com.wandb.hivemind.plist",
    "~/Library/Logs/hivemind",
  ]

  caveats <<~EOS
    This is an UNSTABLE pre-release build — please report issues to
    https://github.com/wandb/hivemind/issues with `hivemind doctor`
    output attached.

    To accept the terms of service, sign in, and start the daemon
    (it registers itself as a login item), run:

        hivemind start

    To switch back to the stable channel:

        brew uninstall --cask wandb/taps/wandb-hivemind-prerelease
        brew install wandb/taps/wandb-hivemind

    Your credentials in ~/.hivemind/ are preserved across the switch.
  EOS
end
