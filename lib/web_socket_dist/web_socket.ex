defmodule WebSocketDist.WebSocket do
  @behaviour TCPFilter.Socket

  defmodule Listen do
    use GenServer

    # client

    def start_link(opts) do
      GenServer.start_link(__MODULE__, %{ controlling_process: self(), opts: opts })
    end

    def accept(listen) do
      GenServer.call(listen, :accept, :infinity)
    end

    def accept(listen, handler) do
      GenServer.cast(listen, {:accept, handler})
    end

    def sockname(listen) do
      GenServer.call(listen, :sockname)
    end

    def close(listen) do
      GenServer.stop(listen)
    end

    # server

    def init(%{ controlling_process: controlling_process, opts: opts }) do
      {:ok, bandit} = Bandit.start_link([
        plug: {
          WebSocketDist.WebSocket.Listen.WebSocketPlug,
          %{ listen: self(), controlling_process: controlling_process }
        }
      ] ++ opts)
      {:ok, %{ bandit: bandit }}
    end

    def handle_call(:sockname, _from, %{ bandit: bandit } = state) do
      {:reply, ThousandIsland.listener_info(bandit), state}
    end

    def handle_call(:accept, from, state) do
      {:noreply, Map.put(state, :accept, from)}
    end

    def handle_cast({:accept, handler}, %{ accept: accept } = state) do
      GenServer.reply(accept, {:ok, handler})
      {:noreply, state}
    end

    def handle_cast({:accept, handler}, state) do
      :error_logger.error_msg(~c"No pending accept loop ** Accepting handler ~p~n", [handler])
      {:noreply, state}
    end

    defmodule WebSocketPlug do
      @behaviour Plug

      def init(args) do
        args
      end

      def call(conn, %{ listen: listen, controlling_process: controlling_process }) do
        peername = {conn.remote_ip, 0}
        conn
          |> WebSockAdapter.upgrade(
            WebSocketDist.WebSocket.Listen.WebSocketHandler, %{ listen: listen, peername: peername, controlling_process: controlling_process },
            []
          )
      end
    end

    defmodule WebSocketHandler do
      @behaviour WebSock

      def init(%{ listen: listen } = args) do
        Listen.accept(listen, self())
        {:ok, args}
      end

      def handle_in({message, [opcode: :binary]}, %{ controlling_process: controlling_process } = state) do
        Kernel.send(controlling_process, message)
        {:ok, state}
      end

      def handle_info({:controlling_process, pid, ack}, state) do
        Kernel.send(ack, :ack)
        {:ok, Map.put(state, :controlling_process, pid)}
      end

      def handle_info({:send, data}, state) do
        {:push, {:binary, data}, state}
      end

      def handle_info({:peername, from}, %{ peername: peername } = state) do
        Kernel.send(from, {:peername, {:ok, peername}})
        {:ok, state}
      end
    end
  end

  defmodule Client do
    use GenServer

    # client

    def start_link(scheme, ip, port, opts) do
      GenServer.start_link(__MODULE__, {self(), scheme, ip, port, opts})
    end

    def controlling_process(client, pid) do
      GenServer.call(client, {:controlling_process, pid})
    end

    def send(client, data) do
      GenServer.call(client, {:send, data})
    end

    def peername(client) do
      GenServer.call(client, :peername)
    end

    # server

    def init({from, scheme, ip, port, opts}) do
      address = :inet.ntoa(ip) |> List.to_string()
      {:ok, conn} = Mint.HTTP.connect(scheme, address, port, opts)
      {:ok, conn, ref} = Mint.WebSocket.upgrade(:ws, conn, "/", [])

      http_reply_message = receive(do: (message -> message))
      {:ok, conn, [{:status, ^ref, status}, {:headers, ^ref, resp_headers}, {:done, ^ref}]} = Mint.WebSocket.stream(conn, http_reply_message)
      {:ok, conn, websocket} = Mint.WebSocket.new(conn, ref, status, resp_headers)

      {:ok, %{
        conn: conn,
        websocket: websocket,
        ref: ref,
        peername: {ip, port},
        controlling_process: from
      }}
    end

    def handle_call({:controlling_process, pid}, _from, state) do
      {:reply, :ok, Map.put(state, :controlling_process, pid)}
    end

    def handle_call({:send, data}, _from, %{ conn: conn, websocket: websocket, ref: ref } = state) do
      data = IO.iodata_to_binary(data)
      {:ok, websocket, data} = Mint.WebSocket.encode(websocket, {:binary, data})
      {:ok, conn} = Mint.WebSocket.stream_request_body(conn, ref, data)
      {:reply, :ok, state
        |> Map.put(:conn, conn)
        |> Map.put(:websocket, websocket)}
    end

    def handle_call(:peername, _from, %{ peername: peername } = state) do
      {:reply, {:ok, peername}, state}
    end

    def handle_info(
      message,
      %{
        conn: conn,
        websocket: websocket,
        ref: ref,
        controlling_process: controlling_process
      } = state
    ) do
      {:ok, conn, [{:data, ^ref, data}]} = Mint.WebSocket.stream(conn, message)
      {:ok, websocket, frames} = Mint.WebSocket.decode(websocket, data)
      {:reply, {:ok, frames}, state
        |> Map.put(:conn, conn)
        |> Map.put(:websocket, websocket)}

      for {:binary, data} <- frames do
        Kernel.send(controlling_process, {:data, data})
      end

      {:noreply, state}
    end
  end

  def family, do: :inet
  def protocol, do: :tcp

  def handle_input({:server, _server}, message) when is_binary(message) do
    {:data, message}
  end

  def handle_input({:client, _client}, {:data, data} = msg) when is_binary(data) do
    msg
  end

  def listen(port, _options) do
    {:ok, listen} = Listen.start_link(port: port)
    {:ok, {:listen, listen}}
  end

  def accept({:listen, listen}) do
    {:ok, handler} = Listen.accept(listen)
    {:ok, {:server, handler}}
  end

  def connect(ip, port, _options) do
    {:ok, client} = Client.start_link(:http, ip, port, [])
    {:ok, {:client, client}}
  end

  def close({:listen, listen}) do
    Listen.close(listen)
    :ok
  end

  def send({:client, client}, data) do
    Client.send(client, data)
  end

  def send({:server, server}, data) do
    Kernel.send(server, {:send, data})
    :ok
  end

  @spec recv({:client, any()} | {:server, any()}, any(), any()) ::
          {:error, :timeout} | {:ok, any()}
  def recv({:server, _server}, _length, timeout) do
    receive do
      message ->
        {:ok, message}
      after
        timeout ->
          {:error, :timeout}
    end
  end

  def recv({:client, _client}, _length, timeout) do
    receive do
      {:data, message} ->
        {:ok, message}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  def controlling_process({:client, client}, pid) do
    Client.controlling_process(client, pid)
  end

  def controlling_process({:server, server}, pid) do
    Kernel.send(server, {:controlling_process, pid, self()})
    receive(do: (:ack -> :noop))
    :ok
  end

  def sockname({:listen, listen}) do
    Listen.sockname(listen)
  end

  def peername({:client, client}) do
    Client.peername(client)
  end

  def peername({:server, server}) do
    Kernel.send(server, {:peername, self()})
    receive(do: ({:peername, peername} -> peername))
  end

  def getopts(_socket, _opts) do
    {:ok, []}
  end

  def setopts({:client, _client}, _opts) do
    :ok
  end

  def setopts({:server, _server}, _opts) do
    :ok
  end

  def getstat(_socket, _opts) do
    {:ok, []}
  end
end
