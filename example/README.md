# WebSocketDist Example
A sample of Erlang Distribution over WebSockets using React and Elixir.

1. Run the server script

```sh
elixir --no-halt --erl "-proto_dist Elixir.TCPFilter -kernel inet_dist_listen_min 5000" server.exs
```

This will start a node on port 5000.

2. Install dependencies and run the web client

```sh
npm install
npm run dev
```

> [!NOTE]
> Installing `@otp-interop/web-socket-dist` requires being [authenticated with GitHub Packages](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry#authenticating-with-a-personal-access-token).

3. Connect multiple tabs for realtime updates

The counter will update live across all tabs.