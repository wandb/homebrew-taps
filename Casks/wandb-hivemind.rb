cask "wandb-hivemind" do
  version "1.1.2"
  sha256 arm: "b0b7cedad168d86a93b5596c0496e53ae70520ab0409ca77f5fa1b31a2e596ff"

  url "https://github.com/wandb/hivemind/releases/download/v#{version}/hivemind-darwin-arm64"
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
  # binary — surface as a binary-link error at install time.
  conflicts_with cask: "wandb/taps/wandb-hivemind-prerelease"
  depends_on arch: :arm64
  depends_on macos: :sonoma

  # Homebrew's launchctl: uninstaller would also delete the managed pkg's
  # /Library/LaunchAgents plist because both installs share this label.
  generated_script "uninstall-launchagent.sh", content: <<~SH
    #!/bin/sh
    set -eu

    label=com.wandb.hivemind
    plist="$HOME/Library/LaunchAgents/$label.plist"
    [ -f "$plist" ] || exit 0
    program=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null) || exit 0
    case "$program" in
      /*) ;;
      *) exit 0 ;;
    esac
    normalize() (
      cd -P "$(dirname "$1")" || exit 1
      printf '%s/%s' "$PWD" "$(basename "$1")"
    )
    program=$(normalize "$program" 2>/dev/null) || exit 0
    links=0
    while [ -L "$program" ]; do
      [ "$links" -lt 16 ] || exit 0
      target=$(readlink "$program" 2>/dev/null) || exit 0
      case "$target" in
        /*) program="$target" ;;
        *) program="$(dirname "$program")/$target" ;;
      esac
      program=$(normalize "$program" 2>/dev/null) || exit 0
      links=$((links + 1))
    done
    case "$program" in
      */Caskroom/wandb-hivemind/*) ;;
      *) exit 0 ;;
    esac
    if [ ! -e "/Library/LaunchAgents/$label.plist" ]; then
      /bin/launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    fi
    /bin/rm -f -- "$plist"
  SH
  binary "hivemind-darwin-arm64", target: "hivemind"

  postflight_steps do
    # The Nuitka onefile binary extracts ~180 MB to ~/.cache on its
    # first execution — several seconds of I/O better paid here than on
    # the user's first command. Best-effort: never fail the install
    # over it (e.g. offline Gatekeeper assessment).
    # Structured steps have a temporary HOME. Resolve the account's home
    # through chdir so the warm-up populates the persistent cache.
    run "/bin/sh",
        args:           ["-c", 'HOME="$(pwd -P)" exec "$1" --version', "--",
                         "{{staged_path}}/hivemind-darwin-arm64"],
        chdir:          "~{{user}}",
        must_succeed:   false,
        print_stdout:   false,
        print_stderr:   false,
        writable_paths: [".cache"],
        writable_base:  :home
  end

  uninstall script: { executable: "uninstall-launchagent.sh" }

  # ~/.hivemind (credentials + sync state) is intentionally not zapped:
  # it is shared by the other install channels (pkg, script, uv tool).
  zap trash: "~/Library/Logs/hivemind"

  caveats <<~EOS
    To accept the terms of service, sign in, and start the daemon
    (it registers itself as a login item), run:

        hivemind start

    Manage it with:

        hivemind status
        hivemind doctor
  EOS
end
