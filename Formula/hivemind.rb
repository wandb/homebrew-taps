class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.1.8/hivemind-0.1.8-py3-none-any.whl"
  sha256 "50d6f29ece19d33a5d2e9a8a5163891d09f59107b8f537aa9cb2cbc854f2df19"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.1.8/agentstream-0.1.8-py3-none-any.whl"
    sha256 "7e2952dda3561bc93b3c23a35bd247ea5f585726c3e0bc16e2e249818b964caf"
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

    if $?.success?
      system "brew", "services", "start", "hivemind"
      ohai "Hivemind daemon started successfully"
    else
      opoo <<~EOS
        Could not authenticate automatically.

        The daemon requires GitHub authentication. Please run:
          gh auth login

        Then start the service:
          brew services start hivemind
      EOS
    end
  end

  service do
    run [opt_bin/"hivemind", "run"]
    keep_alive true
    log_path var/"log/hivemind.log"
    error_log_path var/"log/hivemind.err"
  end

  test do
    assert_match "hivemind", shell_output("#{bin}/hivemind --version")
  end
end
