import JavaScriptKit
import dlmalloc
import ExternalTermFormat

@_expose(wasm, "allocate")
@_cdecl("allocate")
private func _allocate(size: Int) -> UnsafeMutableRawPointer {
    return malloc(size)
}

@_expose(wasm, "deallocate")
@_cdecl("deallocate")
private func _deallocate(allocation: UnsafeMutableRawPointer) {
    free(allocation)
}

@_expose(wasm, "Node_init")
@_cdecl("Node_init")
private func _Node_init(nameStart: UnsafeRawPointer, nameLength: Int, cookieStart: UnsafeRawPointer, cookieLength: Int) -> UnsafeMutableRawPointer {
    let name = String(start: nameStart, length: nameLength)
    let cookie = String(start: cookieStart, length: cookieLength)

    let node = Node(name: name, cookie: cookie)
    return Unmanaged.passRetained(node).toOpaque()
}

@_expose(wasm, "Node_connect")
@_cdecl("Node_connect")
private func _Node_connect(
    nodeAddress: UnsafeRawPointer,
    
    peerStart: UnsafeRawPointer, peerLength: Int,
    nameStart: UnsafeRawPointer, nameLength: Int,

    resolveId: Int,
    rejectId: Int
) {
    let node = Unmanaged<Node>.fromOpaque(nodeAddress).takeUnretainedValue()
    let peer = String(start: peerStart, length: peerLength)
    let name = String(start: nameStart, length: nameLength)
    node.connect(to: peer, name: name) { connection in
        switch connection {
        case let .success(connection):
            WebSocketDistNodePromise.call(
                id: resolveId,
                arguments: JSValue.number(Double(Int(bitPattern: Unmanaged.passRetained(connection).toOpaque())))
            )
        case let .failure(error):
            WebSocketDistNodePromise.call(
                id: rejectId,
                arguments: JSValue.string("Failed to connect: \(error.description)")
            )
        }
    }
}

@_expose(wasm, "Connection_send")
@_cdecl("Connection_send")
private func _Connection_send(
    connectionAddress: UnsafeRawPointer,

    termStart: UnsafeRawPointer, termLength: Int,
    destinationStart: UnsafeRawPointer, destinationLength: Int
) {
    let connection = Unmanaged<Node.Connection>.fromOpaque(connectionAddress).takeUnretainedValue()
    let destination = String(start: destinationStart, length: destinationLength)

    let termBuffer = TermBuffer(Array(UnsafeRawBufferPointer(start: termStart, count: termLength)))

    connection.send(termBuffer, to: destination)
}

@_expose(wasm, "Connection_receive")
@_cdecl("Connection_receive")
private func _Connection_receive(
    connectionAddress: UnsafeRawPointer,

    resolveId: Int,
    rejectId: Int
) {
    let connection = Unmanaged<Node.Connection>.fromOpaque(connectionAddress).takeUnretainedValue()
    
    connection.receive { message in
        guard !message.isEmpty else {
            // try again if we just got the tick message.
            return _Connection_receive(
                connectionAddress: connectionAddress,
                resolveId: resolveId,
                rejectId: rejectId
            )
        }
        do throws(TermDecodingError) {
            var buffer = TermBuffer(message)
            _ = try buffer.decodeVersion()
            guard try buffer.decodeDistributionHeader() == 0 else {
                WebSocketDistNodePromise.call(id: rejectId, arguments: "Failed to decode message")
                return
            }
            let controlMessageStart = buffer.index
            try buffer.skip() // skip the control message tuple
            let controlMessage = buffer.buffer[controlMessageStart..<buffer.index]
            let message = buffer.buffer[buffer.index...]

            WebSocketDistNodePromise.call(
                id: resolveId,
                arguments: JSValue.object(JSTypedArray<UInt8>(controlMessage).jsObject),
                JSValue.object(JSTypedArray<UInt8>(message).jsObject)
            )
        } catch {
            WebSocketDistNodePromise.call(id: rejectId, arguments: "Failed to decode message")
        }
    }
}

struct WebSocketDistNodePromise {
    @discardableResult
    static func call(id: Int, arguments: JSValue...) -> JSValue {
        JSObject.global.__WebSocketDistNodePromiseBuffer[id].function!(arguments: arguments)
    }
}

extension String {
    /// Creates a String instance from a start pointer and length decoded as UTF8.
    init(start: UnsafeRawPointer, length: Int) {
        let buffer = UnsafeRawBufferPointer(start: start, count: length)
        self.init(decoding: buffer, as: UTF8.self)
    }
}