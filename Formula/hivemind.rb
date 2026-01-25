class Hivemind < Formula
  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.1.6/hivemind-0.1.6-py3-none-any.whl"
  sha256 "2dd3d3c995122a74d16b272864682b745226b2b0ed3d7d7ad32211694eec0e97"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.1.6/agentstream-0.1.6-py3-none-any.whl"
    sha256 "9f1c76f244d326127d638003818dbf1ea57b1cf10f5d733817758bb217057705"
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
