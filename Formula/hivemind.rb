class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.2.0/hivemind-0.2.0-py3-none-any.whl"
  sha256 "12ad9d8a009f6005e929188c94bea0170c9f42362ff87eaea4ee223d0fc1a237"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.2.0/agentstream-0.2.0-py3-none-any.whl"
    sha256 "bb1a57d1fb5e2685a13250f3be7d5de4825617a5adfe489ad558d02731bc8f47"
  end

  def install
    venv = virtualenv_create(libexec, "python3.13")
    venv_python = libexec/"bin/python"

    # Install agentstream first (hivemind depends on it)
    resource("agentstream").stage do
      system "python3.13", "-m", "pip",
             "--python=#{venv_python}",
             "install", Dir["*.whl"].first
    end

    # Install hivemind with all its dependencies from PyPI
    system "python3.13", "-m", "pip",
           "--python=#{venv_python}",
           "install", Dir["*.whl"].first

    bin.install_symlink libexec/"bin/hivemind"
  end

  def post_install
    system bin/"hivemind", "auth-check", "--quiet"

    unless $?.success?
      opoo <<~EOS
        GitHub authentication not configured.

        The daemon requires GitHub authentication. Please run:
          gh auth login
      EOS
    end

    ohai <<~EOS
      To start the hivemind daemon:
        brew services start hivemind

      Or run manually:
        hivemind run
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
