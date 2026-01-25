class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.1.7/hivemind-0.1.7-py3-none-any.whl"
  sha256 "14327d56e62a4084ac2cc07845bc0e98a9a51e62bf8ce712b478e27cd16570f9"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.1.7/agentstream-0.1.7-py3-none-any.whl"
    sha256 "37f8f2ab8e43cf521afe843da9f18b2a5ea59f334eac1fe2fd5cf5357d39ffa6"
  end

  def install
    venv = virtualenv_create(libexec, "python3.13")

    resource("agentstream").stage do
      venv.pip_install Dir["*.whl"].first
    end

    venv.pip_install Dir["*.whl"].first

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
