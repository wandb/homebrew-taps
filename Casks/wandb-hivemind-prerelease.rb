cask "wandb-hivemind-prerelease" do
  version "1.1.2rc3"
  sha256 arm: "80c992eb23c0a698e6f231cec9488633d5758a1010ecd7adfab71a46e2c1189f"

  url "https://github.com/wandb/hivemind/releases/download/v#{version}/hivemind-darwin-arm64"
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
      */Caskroom/wandb-hivemind-prerelease/*) ;;
      *) exit 0 ;;
    esac
    if [ ! -e "/Library/LaunchAgents/$label.plist" ]; then
      /bin/launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    fi
    /bin/rm -f -- "$plist"
  SH
  binary "hivemind-darwin-arm64", target: "hivemind"

  postflight_steps do
    # Marker pins the upgrade watcher to the prerelease manifest.
    # Without it, the daemon would silently slide back to stable on the
    # next stable release.
    # XDG_CONFIG_HOME is resolved at install time, so the sandbox needs
    # account-home write access for custom config directories there.
    run "/bin/sh",
        args:           ["-c", <<~'SH', "--"],
          set -e
          HOME="$(pwd -P)"; export HOME
          config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hivemind"
          mkdir -p "$config_dir"
          {
            printf '%s\n' '# Written by wandb-hivemind-prerelease cask postflight.' \
              'method = "brew-cask"' 'channel = "prerelease"'
            printf 'installed_at = "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          } > "$config_dir/install-method"
        SH
        chdir:          "~{{user}}",
        writable_paths: ["~{{user}}"]

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
  zap trash: [
    "~/.config/hivemind/install-method",
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
