class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.1.9/hivemind-0.1.9-py3-none-any.whl"
  sha256 "71ba1f94835a8e07a54e87f998e55c6b73db8b5b36f2e74c8bf021a964689acb"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.1.9/agentstream-0.1.9-py3-none-any.whl"
    sha256 "88616c64aa5a750b26be407d5f3bba0678ba51952224f3f84e91fd81d8aba47f"
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
    run [opt_bin/"hivemind", "run"]
    keep_alive true
    environment_variables HIVEMIND_LOG_FILE: var/"log/hivemind.log"
    log_path var/"log/hivemind.log"
    error_log_path var/"log/hivemind.err"
  end

  test do
    assert_match "hivemind", shell_output("#{bin}/hivemind --version")
  end
end
