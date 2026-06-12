cask "wandb-hivemind" do
  version "0.7.4"
  sha256 arm: "67269d0ae659b440778ea91bdacd36f2c68e60b1f5a0b77d9ce526623de813f2"

  url "https://github.com/wandb/hivemind/releases/download/v#{version}/hivemind-darwin-arm64",
      verified: "github.com/wandb/hivemind/"
  name "W&B HiveMind"
  desc "Daemon that syncs AI coding sessions to a shared W&B dashboard"
  homepage "https://hivemind.wandb.tools/"

  # Same manifest the daemon's upgrade watcher reads.
  livecheck do
    url "https://raw.githubusercontent.com/wandb/hivemind/main/manifests/hivemind-latest.json"
    strategy :json do |json|
      json["version"]
    end
  end

  # The daemon self-updates in place; `brew upgrade` is a no-op for this
  # cask unless --greedy is passed.
  auto_updates true
  # Cask conflicts_with only accepts cask:. The formula collisions —
  # homebrew-core's hivemind (unrelated Procfile process manager) and
  # the legacy wandb/taps/hivemind formula also install a `hivemind`
  # binary — surface as a binary-link error at install time and are
  # called out in the caveats.
  conflicts_with cask: "wandb/taps/wandb-hivemind-prerelease"
  depends_on arch: :arm64
  depends_on macos: :big_sur

  binary "hivemind-darwin-arm64", target: "hivemind"

  # `hivemind start` registers this label; remove it with the binary so
  # launchd doesn't KeepAlive-respawn a deleted executable.
  uninstall launchctl: "com.wandb.hivemind"

  # ~/.hivemind (credentials + sync state) is intentionally not zapped:
  # it is shared by the other install channels (pkg, script, uv tool).
  zap trash: [
    "~/Library/LaunchAgents/com.wandb.hivemind.plist",
    "~/Library/Logs/hivemind",
  ]

  caveats <<~EOS
    To accept the terms of service, sign in, and start the daemon
    (it registers itself as a login item), run:

        hivemind start

    Manage it with:

        hivemind status
        hivemind doctor

    This cask cannot be installed alongside formulae that also provide
    a `hivemind` command (homebrew-core's hivemind process manager, or
    the legacy wandb/taps/hivemind formula) — uninstall those first.
  EOS
end
