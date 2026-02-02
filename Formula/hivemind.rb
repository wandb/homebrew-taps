class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.3.1/hivemind-0.3.1-py3-none-any.whl"
  sha256 "2439fe36edb25db416eddb75dcc4b45740107bc197283f427b0b887e0d366228"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.3.1/agentstream-0.3.1-py3-none-any.whl"
    sha256 "06b61d30dbb645efd903eeb355ae62e3e764b9f155c23b42d89df870f2ae7583"
  end

  def install
    venv = virtualenv_create(libexec, "python3.13", system_site_packages: false)
    venv_python = libexec/"bin/python"

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
    # Check authentication silently
    system bin/"hivemind", "auth-check", "--quiet"

    unless $?.success?
      opoo <<~EOS
        GitHub authentication not configured.
        Run: gh auth login
      EOS
    end

    # Check if service is running (upgrade scenario)
    plist_path = Pathname.new("#{Dir.home}/Library/LaunchAgents/com.wandb.hivemind.plist")
    if plist_path.exist?
      output = Utils.popen_read("launchctl", "list") rescue ""
      if output.include?("com.wandb.hivemind")
        ohai "Restart the service to apply the update: brew services restart wandb/taps/hivemind"
      end
    end
  end

  def caveats
    <<~EOS
      To start hivemind now and restart at login:
        brew services start wandb/taps/hivemind

      Or run manually:
        hivemind run

      Note: Use the fully-qualified formula name (wandb/taps/hivemind) to avoid
      conflicts with the unrelated 'hivemind' package in homebrew-core.
    EOS
  end

  service do
    name macos: "com.wandb.hivemind"
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
