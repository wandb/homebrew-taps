class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.4.0/wandb_hivemind-0.4.0-py3-none-any.whl"
  sha256 "74bdbf77745af318e707f72bbe1e945cbbe31e8234be5b025c15164fa1ace47f"
  license "MIT"

  # Requires Python >= 3.13 (update formula when Homebrew moves to newer Python)
  depends_on "python@3.13"
  depends_on "pydantic"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.4.0/wandb_agentstream-0.4.0-py3-none-any.whl"
    sha256 "8d072a55b4f38e293da425cc9c3f719242b60ea4974e1a15f93b899e94e0fee8"
  end

  def install
    # Use system_site_packages to access Homebrew's pydantic (which has
    # pre-built bottles that don't cause relocation errors)
    venv = virtualenv_create(libexec, "python3.13", system_site_packages: true)
    venv_python = libexec/"bin/python"

    # Uninstall old hivemind/agentstream from system Python if present.
    # Older formula versions (< 0.3.3) used venv.pip_install which could
    # leave packages in the system site-packages. With system_site_packages
    # enabled, those stale packages shadow the virtualenv versions and cause
    # the daemon to run old code despite showing the new version number.
    %w[hivemind agentstream wandb-hivemind wandb-agentstream].each do |pkg|
      if quiet_system("python3.13", "-m", "pip", "show", "--quiet", pkg)
        ohai "Removing stale #{pkg} from system site-packages"
        system "python3.13", "-m", "pip", "uninstall", "--yes", "--quiet", pkg
      end
    end

    # Install agentstream first (hivemind depends on it)
    resource("agentstream").stage do
      system "python3.13", "-m", "pip",
             "--python=#{venv_python}",
             "install", "--quiet", Dir["*.whl"].first
    end

    # Install hivemind with all its dependencies from PyPI
    system "python3.13", "-m", "pip",
           "--python=#{venv_python}",
           "install", "--quiet", Dir["*.whl"].first

    bin.install_symlink libexec/"bin/hivemind"
  end

  def post_install
    # Check if service is running and prompt for restart
    plist_path = Pathname.new("#{Dir.home}/Library/LaunchAgents/com.wandb.hivemind.plist")
    if plist_path.exist?
      ohai "Service installed. Restart to apply update: brew services restart wandb/taps/hivemind"
    end
  end

  def caveats
    <<~EOS
      To start hivemind now and restart at login:
        brew services start wandb/taps/hivemind

      Or, to run manually:
        hivemind start

      Management commands:
        hivemind status    # Check daemon status
        hivemind stop      # Stop the daemon
        hivemind restart   # Restart the daemon
        hivemind logs      # View daemon logs
        hivemind doctor    # Diagnose issues

      Note: Use the fully-qualified formula name (wandb/taps/hivemind) to avoid
      conflicts with the unrelated 'hivemind' package in homebrew-core.
    EOS
  end

  service do
    name macos: "com.wandb.hivemind", linux: "hivemind"
    run [opt_bin/"hivemind", "run"]
    keep_alive true
    working_dir var
    environment_variables HIVEMIND_LOG_FILE: var/"log/hivemind.log"
    log_path var/"log/hivemind.log"
    error_log_path var/"log/hivemind.err"
  end

  test do
    assert_match "hivemind", shell_output("#{bin}/hivemind --version")
  end
end
