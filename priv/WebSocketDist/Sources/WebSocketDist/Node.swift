import JavaScriptKit
import ExternalTermFormat

extension Array {
    mutating func take(first count: Index) -> Self.SubSequence {
        defer { self.removeFirst(count) }
        return self.prefix(count)
    }
}

extension JSTypedArray where Traits == UInt8 {
    var arrayBuffer: JSObject {
        jsObject.buffer.object!
    }
}

/// ```swift
/// let node = Node(name: "web@127.0.0.1", cookie: "LJTPNYYQIOIRKYDCWCQH")
/// let connection = try await node.connect(to: "192.168.1.45:50755", name: "server@127.0.0.1")
/// print(connection)
/// await connection.sendTest()
/// ```
final class Node {
    let name: String
    let cookie: String

    let flags: Flags
    let creation: UInt32

    init(name: String, cookie: String) {
        self.name = name
        self.cookie = cookie
        self.flags = [
            .mandatory25Digest,
            .distMandatory,
            .distMonitor,
            .smallAtomTags,
            .fragments
        ]
        
        self.creation = 0
    }

    func connect(to peer: String, name: String, completion: @escaping (Result<Connection, Connection.ConnectionError>) -> ()) {
        var connection: Connection!
        connection = Connection(node: self, peer: peer, name: name) {
            connection.connect { result in
                switch result {
                case .success: 
                    return completion(.success(connection))
                case let .failure(error):
                    return completion(.failure(error))
                }
            }
        }
    }

    final class Connection {
        var node: Node

        /// The address of the peer node.
        let peer: String
        /// The name of the peer node.
        let peerName: String
        /// The flags the peer node returns.
        var peerFlags: Flags = []
        /// The creation value the peer node returns.
        var peerCreation: UInt32 = 0
        
        var socket: JSObject

        typealias Message = [UInt8]
        var messages = [Message]()
        var messageContinuations = [(Message) -> ()]()
        func receive(_ callback: @escaping (Message) -> ()) {
            if let message = messages.popLast() {
                callback(message)
            } else {
                messageContinuations.insert(callback, at: 0) // add to the end of the queue
            }
        }

        init(
            node: Node,
            peer: String,
            name: String,
            completion: @escaping () -> ()
        ) {
            self.node = Unmanaged.passUnretained(node).takeUnretainedValue()
            self.peer = peer
            self.peerName = name
            self.socket = JSObject.global.WebSocket.function!.new("ws://\(peer)")
            socket.binaryType = "arraybuffer"
            socket.onmessage = JSClosure { [self] arguments in
                let event = arguments[0].object!
                let data = JSTypedArray<UInt8>(unsafelyWrapping: JSObject.global.Uint8Array.function!.new(event.data)).withUnsafeBytes {
                    [UInt8]($0)
                }
                // guard data != [] else { return .undefined } // empty tick message
                // if anyone is waiting for a message, continue there
                if let continuation = self.messageContinuations.popLast() {
                    continuation(data)
                } else {
                    self.messages.insert(data, at: 0)
                }
                return .undefined
            }.jsValue
            socket.onopen = JSClosure { _ in
                completion()
                return .undefined
            }.jsValue
            socket.onerror = JSClosure { arguments in
                let event = arguments[0].object!
                fatalError(event.description)
            }.jsValue
        }

        func connect(completion: @escaping (Result<(), ConnectionError>) -> ()) {
            sendName()
            receiveStatus { status in
                switch status {
                case .success: break
                case let .failure(error): return completion(.failure(error))
                }
                
                self.receiveChallenge { result in
                    switch result {
                    case let .success(peerChallenge):
                        let digest = self.generateDigest(challenge: peerChallenge, cookie: self.node.cookie)
                        let challenge = self.generateChallenge()
                        self.sendChallengeReply(for: challenge, digest: digest)
                        
                        self.receiveChallengeAcknowledgement(for: challenge) { result in
                            switch result {
                            case .success: return completion(.success(()))
                            case let .failure(error): return completion(.failure(error))
                            }
                        }
                    case let .failure(error): return completion(.failure(error))
                    }
                }
                
            }
            
        }

        private func generateDigest(challenge: UInt32, cookie: String) -> [UInt8] {
            return (cookie + String(challenge)).utf8.md5.bytes
        }

        private func generateChallenge() -> UInt32 {
            return UInt32.random(in: UInt32.min...UInt32.max)
        }

        private func sendName() {
            var message = [UInt8]()

            // name tag
            message.append(MessageTag.sendNameTag.rawValue)

            // flags
            withUnsafeBytes(of: node.flags.rawValue.bigEndian) {
                message.append(contentsOf: $0)
            }

            // creation
            withUnsafeBytes(of: node.creation.bigEndian) {
                message.append(contentsOf: $0)
            }

            // name length
            withUnsafeBytes(of: UInt16(node.name.utf8.count).bigEndian) {
                message.append(contentsOf: $0)
            }

            // name
            message.append(contentsOf: node.name.utf8)

            _ = socket.send!(JSTypedArray<UInt8>(message).arrayBuffer)
            
            _ = JSObject.global.console.info("HANDSHAKE sendName")
        }

        private func receiveStatus(completion: @escaping (Result<(), ConnectionError>) -> ()) {
            receive { message in
                var message = message
                guard message.removeFirst() == ResponseTag.challengeStatus.rawValue
                else { return completion(.failure(ConnectionError.protocolError)) }

                guard message == [111, 107] // 'o' 'k'
                else { return completion(.failure(ConnectionError.receiveStatus(message))) }

                _ = JSObject.global.console.info("HANDSHAKE receiveStatus 'ok'")
                completion(.success(()))
            }
        }

        private func receiveChallenge(completion: @escaping (Result<UInt32, ConnectionError>) -> ()) {
            receive { message in
                var message = message

                switch message.removeFirst() {
                case NodeType.node.rawValue:
                    self.peerFlags = message.take(first: 8).withUnsafeBytes {
                        Flags(rawValue: UInt64(bigEndian: $0.load(as: UInt64.self)))
                    }
                    if !self.peerFlags.contains(.mandatory25Digest) {
                        self.peerFlags.insert(.mandatory25Digest)
                    }
                    if !self.peerFlags.contains(.handshake23) {
                        return completion(.failure(ConnectionError.challengeMissing(.handshake23)))
                    }
                    let challenge = message.take(first: 4).withUnsafeBytes {
                        UInt32(bigEndian: $0.load(as: UInt32.self))
                    }
                    
                    self.peerCreation = message.take(first: 4).withUnsafeBytes {
                        UInt32(bigEndian: $0.load(as: UInt32.self))
                    }

                    let nameLength = message.take(first: 2).withUnsafeBytes {
                        UInt16(bigEndian: $0.load(as: UInt16.self))
                    }

                    let name = Array(message.take(first: Int(nameLength)))
                    guard name == Array(self.peerName.utf8)
                    else { return completion(.failure(ConnectionError.wrongPeerName(name))) }

                    _ = JSObject.global.console.info("HANDSHAKE receiveChallenge '\(challenge)'")

                    return completion(.success(challenge))
                default:
                    return completion(.failure(ConnectionError.unexpectedPeerType))
                }
            }
        }

        private func sendChallengeReply(for challenge: UInt32, digest: [UInt8]) {
            var message = [UInt8]()

            // tag
            message.append(MessageTag.challengeReply.rawValue)

            // challenge
            withUnsafeBytes(of: challenge.bigEndian) {
                message.append(contentsOf: $0)
            }

            // digest
            message.append(contentsOf: digest)

            _ = socket.send!(JSTypedArray<UInt8>(message).arrayBuffer)

            _ = JSObject.global.console.info("HANDSHAKE sendChallengeReply challenge=\(challenge) digest=\(digest) local=\(node.name)")
        }

        private func receiveChallengeAcknowledgement(for challenge: UInt32, completion: @escaping (Result<(), ConnectionError>) -> ()) {
            receive { message in
                var message = message

                // tag
                guard message.removeFirst() == ResponseTag.challengeAck.rawValue
                else { return completion(.failure(ConnectionError.protocolError)) }

                let peerDigest = message.take(first: 16)
                let ourDigest = self.generateDigest(challenge: challenge, cookie: self.node.cookie)

                guard Array(peerDigest) == ourDigest
                else { return completion(.failure(ConnectionError.peerAuthenticationError)) }

                _ = JSObject.global.console.info("HANDSHAKE receiveChallengeAcknowledgement")
                completion(.success(()))
            }
        }

        func send(_ term: TermBuffer, to destination: String) {
            var message = TermBuffer()
            message.encodeVersion()
            message.encodeDistributionHeader()

            // control message
            message.encodeSmallTupleHeader(arity: 4)
            message.encodeSmallInteger(6) // REG_SEND
            message.encodePID(PID(node: node.name, id: 0, serial: 0, creation: node.creation)) // sender
            message.encodeSmallAtomUTF8("") // unused
            message.encodeSmallAtomUTF8(destination)

            // payload
            message.append(contentsOf: term.buffer)

            _ = socket.send!(JSTypedArray<UInt8>(message.buffer).arrayBuffer)
        }

        enum ConnectionError: Error, CustomStringConvertible {
            case socketError(String)
            
            case protocolError
            
            case receiveStatus([UInt8])

            case challengeMissing(Flags)

            case wrongPeerName([UInt8])

            case unexpectedPeerType

            case peerAuthenticationError

            var description: String {
                switch self {
                case let .socketError(error):
                    return "Socket error: \(error)"
                case .protocolError:
                    return "Protocol error"
                case let .receiveStatus(status):
                    return "Receive status: \(status)"
                case let .challengeMissing(flags):
                    return "Challenge missing: \(flags)"
                case let .wrongPeerName(peerName):
                    return "Wrong peer name: \(peerName)"
                case .unexpectedPeerType:
                    return "Unexpected peer type"
                case .peerAuthenticationError:
                    return "Peer authentication error"
                }
            }
        }
    }
}