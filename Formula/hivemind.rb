class Hivemind < Formula
  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/agentstream-py/releases/download/v0.1.2/hivemind-0.1.2.tar.gz"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/agentstream-py/releases/download/v0.1.2/agentstream-0.1.2-py3-none-any.whl"
    sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
  end

  resource "hivemind" do
    url "https://github.com/wandb/agentstream-py/releases/download/v0.1.2/hivemind-0.1.2-py3-none-any.whl"
    sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
  end

  def install
    venv = virtualenv_create(libexec, "python3.13")

    resource("agentstream").stage do
      venv.pip_install Dir["*.whl"].first
    end

    resource("hivemind").stage do
      venv.pip_install Dir["*.whl"].first
    end

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
