# web_socket_dist

Erlang distribution over WebSockets.

Use the `WebSocketDist.WebSocket` module with [`tcp_filter_dist`](https://github.com/otp-interop/tcp_filter_dist) to perform Erlang distribution over WebSockets.

```elixir
TCPFilter.set_socket(WebSocketDist.WebSocket)
```

You can also set this socket when starting the TCPFilter in your supervisor:

```elixir
{TCPFilter, filter: MyApp.Filter, socket: TCPFilter.SSLSocket, name: TCPFilter}
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `web_socket_dist` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:web_socket_dist, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/web_socket_dist>.

## Example
You can find a complete realtime counter sample in [`example/`](/example).

https://github.com/user-attachments/assets/deaef5c4-1b62-47d3-8898-5af9b6cd96b4

