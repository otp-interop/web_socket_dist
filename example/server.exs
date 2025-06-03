Mix.install([{:web_socket_dist, github: "otp-interop/web_socket_dist"}])

defmodule Counter do
  def start_link() do
    {:ok, count} = Agent.start_link(fn -> 0 end)
    {:ok, spawn_link(__MODULE__, :start, [count])}
  end

  def start(count) do
    :net_kernel.monitor_nodes(true, [{:node_type, :hidden}])
    receive_loop(count)
  end

  def receive_loop(count) do
    receive do
      ~c"increment" ->
        Agent.update(count, fn count -> count + 1 end)
      ~c"decrement" ->
        Agent.update(count, fn count -> count - 1 end)
      {:nodeup, node, _} ->
        Agent.get(count, fn value ->
          send({:counter, node}, value)
        end)
      {:nodedown, _, _} ->
        :noop
      other ->
        :error_logger.error_msg("Received unexpected message")
        dbg other
    end
    Agent.get(count, fn value ->
      for node <- Node.list(:hidden) do
        send({:counter, node}, value)
      end
    end)
    receive_loop(count)
  end
end

TCPFilter.start_link(socket: WebSocketDist.WebSocket, name: TCPFilter)
Node.start(:"server@127.0.0.1")
Node.set_cookie(Node.self(), :cookie)

{:ok, counter} = Counter.start_link()
Process.register(counter, :counter)
