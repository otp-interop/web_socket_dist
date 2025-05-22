defmodule WebSocketDist.MixProject do
  use Mix.Project

  def project do
    [
      app: :web_socket_dist,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tcp_filter_dist, git: "https://github.com/otp-interop/tcp_filter_dist.git", branch: "main"},
      {:bandit, "~> 1.0"},
      {:mint_web_socket, "~> 1.0.4"},
      {:websock_adapter, "~> 0.5.8"}
    ]
  end
end
