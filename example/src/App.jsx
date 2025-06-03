import { useMemo, useState, useRef, useEffect } from 'react'
import './App.css'

import { Packer, Unpacker } from 'wetf'

import { Node } from '@otp-interop/web-socket-dist'

function App() {
  const nodeName = useMemo(() => `${crypto.randomUUID()}@127.0.0.1`, [])
  const packer = useMemo(() => new Packer(), [])
  const unpacker = useMemo(() => new Unpacker(), [])
  
  const [count, setCount] = useState(0)

  const node = useMemo(() => new Node(nodeName, "cookie"), [nodeName])
  const [connection, setConnection] = useState(undefined)

  const connect = async () => {
    if (!node) return
    const connection = await node.connect("localhost:5000", "server@127.0.0.1")
    setConnection(connection)
  }

  const isReceiving = useRef(false)
  useEffect(() => {
    if (!connection || isReceiving.current) return

    async function receiveLoop() {
      isReceiving.current = true
      try {
        while (connection) {
          const [, message] = await connection.receive()
          setCount(unpacker.unpack(message))
        }
      } finally {
        isReceiving.current = false
      }
    }
    receiveLoop()
  }, [connection, unpacker])

  const increment = () => {
    if (!connection) return
    // shift, because message should not have a version header
    connection.send("counter", packer.pack("increment").subarray(1))
  }
  const decrement = () => {
    if (!connection) return
    // shift, because message should not have a version header
    connection.send("counter", packer.pack("decrement").subarray(1))
  }

  return (
    <main className="flex flex-col gap-4 items-center">
      <h1>Web Socket Distribution Example</h1>
      {
        connection
        ? <>
          <p className="text-5xl">{count}</p>
          <div className="flex flex-row gap-2">
            <button onClick={decrement}>Decrement</button>
            <button onClick={increment}>Increment</button>
          </div>
        </>
        : <button onClick={connect}>Connect</button>
      }
    </main>
  )
}

export default App
