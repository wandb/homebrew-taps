class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.3.0/hivemind-0.3.0-py3-none-any.whl"
  sha256 "2a6b03e36544af03fa3fd616145a5d517a75b2a65dfa9f505391d45e166ec90a"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.3.0/agentstream-0.3.0-py3-none-any.whl"
    sha256 "03638bae15c7c04e65075478dce12c1e8f1c21ce745cd88e8644eb0cf6d03a38"
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
