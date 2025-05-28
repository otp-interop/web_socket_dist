// The Swift Programming Language
// https://docs.swift.org/swift-book

import JavaScriptEventLoop
import JavaScriptKit
import WebSockets
import DOM
import WASILibc
import ExternalTermFormat

JavaScriptEventLoop.installGlobalExecutor()

enum NodeType: Character {
    case node = "N"
}

enum MessageTag: Character {
    case sendNameTag = "N"
    case challengeReply = "r"
}

enum ResponseTag: Character {
    case challengeStatus = "s"
    case challengeAck = "a"
}

extension Array {
    mutating func take(first count: Index) -> Self.SubSequence {
        defer { self.removeFirst(count) }
        return self.prefix(count)
    }
}

extension Node {
    struct Flags: OptionSet {
        let rawValue: UInt64

        // Individual flags
        static let published                = Flags(rawValue: 0x01)
        static let atomCache                = Flags(rawValue: 0x02)
        static let extendedReferences       = Flags(rawValue: 0x04)
        static let distMonitor              = Flags(rawValue: 0x08)
        static let funTags                  = Flags(rawValue: 0x10)
        static let distMonitorName          = Flags(rawValue: 0x20)
        static let hiddenAtomCache          = Flags(rawValue: 0x40)
        static let newFunTags               = Flags(rawValue: 0x80)
        static let extendedPidsPorts        = Flags(rawValue: 0x100)
        static let exportPtrTag             = Flags(rawValue: 0x200)
        static let bitBinaries              = Flags(rawValue: 0x400)
        static let newFloats                = Flags(rawValue: 0x800)
        static let unicodeIO                = Flags(rawValue: 0x1000)
        static let distHdrAtomCache         = Flags(rawValue: 0x2000)
        static let smallAtomTags            = Flags(rawValue: 0x4000)
        static let etsCompressed            = Flags(rawValue: 0x8000) // internal
        static let utf8Atoms                = Flags(rawValue: 0x10000)
        static let mapTag                   = Flags(rawValue: 0x20000)
        static let bigCreation              = Flags(rawValue: 0x40000)
        static let sendSender               = Flags(rawValue: 0x80000)
        static let bigSeqtraceLabels        = Flags(rawValue: 0x100000)
        static let pendingConnect           = Flags(rawValue: 0x200000) // internal
        static let exitPayload              = Flags(rawValue: 0x400000)
        static let fragments                = Flags(rawValue: 0x800000)
        static let handshake23              = Flags(rawValue: 0x1000000)
        static let unlinkID                 = Flags(rawValue: 0x2000000)
        static let mandatory25Digest        = Flags(rawValue: 0x4000000)
        static let reserved                 = Flags(rawValue: 0xf8000000)

        // Flags shifted by 32 bits
        static let spawn                    = Flags(rawValue: 0x1 << 32)
        static let nameMe                   = Flags(rawValue: 0x2 << 32)
        static let v4NC                     = Flags(rawValue: 0x4 << 32)
        static let alias                    = Flags(rawValue: 0x8 << 32)
        static let localExt                 = Flags(rawValue: 0x10 << 32) // internal
        static let altactSig                = Flags(rawValue: 0x20 << 32)

        // Combined flags
        static let distMandatory25: Flags = [
            .extendedReferences,
            .funTags,
            .extendedPidsPorts,
            .utf8Atoms,
            .newFunTags,
            .bigCreation,
            .newFloats,
            .mapTag,
            .exportPtrTag,
            .bitBinaries,
            .handshake23
        ]

        static let distMandatory26: Flags = [
            .v4NC,
            .unlinkID
        ]

        static let distMandatory: Flags = [
            .distMandatory25,
            .distMandatory26
        ]

        static let distHopefully: Flags = [
            .distMonitor,
            .distMonitorName,
            .spawn,
            .altactSig,
            .alias
        ]

        static let distDefault: Flags = [
            .distMandatory,
            .distHopefully,
            .unicodeIO,
            .distHdrAtomCache,
            .smallAtomTags,
            .sendSender,
            .bigSeqtraceLabels,
            .exitPayload,
            .fragments,
            .spawn,
            .alias,
            .mandatory25Digest
        ]
    }
}

actor Node {
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
        
        var creation = UInt64()
        time(&creation)
        self.creation = UInt32(truncatingIfNeeded: creation)
    }

    func connect(to peer: String, name: String) async throws -> Connection {
        let connection = try await Connection(node: self, peer: peer, name: name)
        try await connection.connect()
        return connection
    }

    actor Connection {
        unowned var node: Node
        /// The address of the peer node.
        let peer: String
        /// The name of the peer node.
        let peerName: String
        /// The flags the peer node returns.
        var peerFlags: Flags = []
        /// The creation value the peer node returns.
        var peerCreation: UInt32 = 0
        
        let socket: WebSocket

        typealias Message = [UInt8]
        var messages = [Message]()
        var messageContinuations = [@Sendable (sending Message) -> ()]()
        func receive() async -> Message {
            if let message = messages.popLast() {
                return message
            } else {
                return await withCheckedContinuation { continuation in
                    messageContinuations.insert(continuation.resume(returning:), at: 0) // add to the end of the queue
                }
            }
        }

        init(
            node: Node,
            peer: String,
            name: String
        ) async throws {
            self.node = node
            self.peer = peer
            self.peerName = name
            self.socket = WebSocket(url: "ws://\(peer)")
            socket.binaryType = .arraybuffer
            socket.onmessage = { [self] event in
                // if anyone is waiting for a message, continue there
                if let continuation = self.messageContinuations.popLast() {
                    let buffer = ArrayBuffer(from: event.jsObject.data)!
                    Uint8Array(buffer).withUnsafeBytes { bytes in
                        continuation([UInt8](bytes))
                    }
                } else {
                    self.messages.insert([], at: 0)
                }
                return .undefined
            }
            try await withCheckedThrowingContinuation { [socket] continuation in
                socket.onopen = { event in
                    continuation.resume()
                    return .undefined
                }
                socket.onerror = { event in
                    continuation.resume(throwing: ConnectionError.socketError(event.description))
                    return .undefined
                }
            }
            print("Socket opened")
        }

        func connect() async throws {
            print("Connecting...")
            
            try await sendName()
            try await receiveStatus()
            
            let peerChallenge = try await receiveChallenge()
            
            let digest = generateDigest(challenge: peerChallenge, cookie: node.cookie)
            let challenge = generateChallenge()
            try await sendChallengeReply(for: challenge, digest: digest)
            
            try await receiveChallengeAcknowledgement(for: challenge)
        }

        private func generateDigest(challenge: UInt32, cookie: String) -> [UInt8] {
            return (cookie + String(challenge)).utf8.md5.bytes
        }

        private func generateChallenge() -> UInt32 {
            return UInt32.random(in: UInt32.min...UInt32.max)
        }

        private func sendName() async throws {
            var message = [UInt8]()

            // name tag
            message.append(MessageTag.sendNameTag.rawValue.asciiValue!)

            // flags
            withUnsafeBytes(of: node.flags.rawValue.bigEndian) {
                message.append(contentsOf: $0)
            }

            // creation
            withUnsafeBytes(of: node.creation.bigEndian) {
                message.append(contentsOf: $0)
            }

            // name length
            withUnsafeBytes(of: UInt16(node.name.count).bigEndian) {
                message.append(contentsOf: $0)
            }

            // name
            message.append(contentsOf: node.name.utf8)

            print(message)

            socket.send(data: .bufferSource(.arrayBuffer(Uint8Array(message).arrayBuffer)))
            
            print("HANDSHAKE sendName")
        }

        private func receiveStatus() async throws {
            var message = await receive()

            guard message.removeFirst() == ResponseTag.challengeStatus.rawValue.asciiValue
            else { throw ConnectionError.protocolError }

            let status = String(bytes: message, encoding: .utf8)
            guard status == "ok"
            else { throw ConnectionError.receiveStatus(status) }

            print("HANDSHAKE receiveStatus 'ok'")
        }

        private func receiveChallenge() async throws -> UInt32 {
            var message = await receive()

            switch message.removeFirst() {
            case NodeType.node.rawValue.asciiValue:
                self.peerFlags = message.take(first: 8).withUnsafeBytes {
                    Flags(rawValue: UInt64(bigEndian: $0.load(as: UInt64.self)))
                }
                if !peerFlags.contains(.mandatory25Digest) {
                    peerFlags.insert(.mandatory25Digest)
                }
                if !peerFlags.contains(.handshake23) {
                    throw ConnectionError.challengeMissing(.handshake23)
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

                let name = String(bytes: message.take(first: Int(nameLength)), encoding: .utf8)
                guard name == self.peerName
                else { throw ConnectionError.wrongPeerName(name) }

                print("HANDSHAKE receiveChallenge '\(challenge)'")

                return challenge
            default:
                throw ConnectionError.unexpectedPeerType
            }
        }

        private func sendChallengeReply(for challenge: UInt32, digest: [UInt8]) async throws {
            var message = [UInt8]()

            // tag
            message.append(MessageTag.challengeReply.rawValue.asciiValue!)

            // challenge
            withUnsafeBytes(of: challenge.bigEndian) {
                message.append(contentsOf: $0)
            }

            // digest
            message.append(contentsOf: digest)

            socket.send(data: .bufferSource(.arrayBuffer(Uint8Array(message).arrayBuffer)))

            print("HANDSHAKE sendChallengeReply challenge=\(challenge) digest=\(digest.map { String(format: "%02x", $0) }.joined()) local=\(node.name)")
        }

        private func receiveChallengeAcknowledgement(for challenge: UInt32) async throws {
            var message = await receive()
            
            // tag
            guard message.removeFirst() == ResponseTag.challengeAck.rawValue.asciiValue
            else { throw ConnectionError.protocolError }

            let peerDigest = message.take(first: 16)
            let ourDigest = generateDigest(challenge: challenge, cookie: node.cookie)

            guard Array(peerDigest) == ourDigest
            else { throw ConnectionError.peerAuthenticationError }

            print("HANDSHAKE receiveChallengeAcknowledgement")
        }

        func sendTest() {
            print("Sending test payload '5' to registered process 'foo'")

            var message = TermBuffer()
            message.encodeVersion()
            message.encodeDistributionHeader()
            
            // control message
            message.encodeSmallTupleHeader(arity: 4)
            message.encodeSmallInteger(6) // REG_SEND
            message.encodePID(PID(node: node.name, id: 0, serial: 0, creation: node.creation)) // sender
            message.encodeSmallAtomUTF8("") // unused
            message.encodeSmallAtomUTF8("foo") // destination

            // payload
            message.encodeSmallInteger(5)
            
            print(message.buffer)

            socket.send(data: .bufferSource(.arrayBuffer(Uint8Array(message.buffer).arrayBuffer)))
        }

        enum ConnectionError: Error {
            case socketError(String)
            
            case protocolError
            
            case receiveStatus(String?)

            case challengeMissing(Flags)

            case wrongPeerName(String?)

            case unexpectedPeerType

            case peerAuthenticationError
        }
    }
}

let node = Node(name: "web@127.0.0.1", cookie: "LJTPNYYQIOIRKYDCWCQH")
let connection = try await node.connect(to: "192.168.1.45:50755", name: "server@127.0.0.1")
print(connection)
await connection.sendTest()