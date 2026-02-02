class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.3.2/hivemind-0.3.2-py3-none-any.whl"
  sha256 "019f41524170ea75bec04090795f5fbde46107f2bb0a4ff80bb8b2642a6e9920"
  license "MIT"

  depends_on "python@3.13"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.3.2/agentstream-0.3.2-py3-none-any.whl"
    sha256 "ae83b92c07076108ce64d949b8522f7fc1d59d9440c9dee57aca534a4e9f2cb8"
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
    # Note: We intentionally skip auth-check here because it can trigger
    # credential migration which breaks a still-running older daemon.
    # Users will be prompted to authenticate when they start the service.
    true
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
    restart_service :changed
  end

  test do
    assert_match "hivemind", shell_output("#{bin}/hivemind --version")
  end
end
