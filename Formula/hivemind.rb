class Hivemind < Formula
  include Language::Python::Virtualenv

  desc "Syncs agentic coding sessions to Weights & Biases"
  homepage "https://github.com/wandb/agentstream-py"
  url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.4.3/wandb_hivemind-0.4.3-py3-none-any.whl"
  sha256 "c8fb452e7a93783c2d9bbf90a17d8050fd0278dbb20c698f1f01aaa4b7fdd8f0"
  license "MIT"

  # Requires Python >= 3.13 (update formula when Homebrew moves to newer Python)
  depends_on "python@3.13"
  depends_on "pydantic"

  resource "agentstream" do
    url "https://github.com/wandb/homebrew-taps/releases/download/hivemind-v0.4.3/wandb_agentstream-0.4.3-py3-none-any.whl"
    sha256 "a94471645bcc2d79e62cfb5a0b52c3be13c7930ae13028da55491b1d4eb50c5d"
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
    # Print dynamic post-install summary (auth check, health, service guidance).
    # The --post-install flag produces user-friendly output and always exits 0
    # so it never fails the brew install/upgrade.
    system opt_bin/"hivemind", "doctor", "--post-install"
  end

  def caveats
    <<~EOS
      Run `hivemind restart` to pick up the new version.

      Manage the daemon with:  hivemind start | stop | restart | status
      Diagnostics:             hivemind doctor

      Note: Use the fully-qualified tap name (wandb/taps/hivemind) for brew
      commands to avoid conflicts with homebrew-core's unrelated 'hivemind'.
    EOS
  end

  def post_uninstall
    %w[.claude .codex .cursor].each do |dir|
      agent_file = Pathname.new(Dir.home) / dir / "agents" / "wandb-hivemind.md"
      next unless agent_file.exist?
      # Only remove if it's our file (contains our frontmatter marker)
      content = agent_file.read rescue next
      next unless content.include?("name: hivemind")
      ohai "Removing @hivemind agent from ~/#{dir}/agents/"
      agent_file.delete
    end
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
