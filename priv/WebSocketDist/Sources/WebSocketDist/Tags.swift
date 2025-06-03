enum NodeType: UInt8 {
    case node = 78 // N
}

enum MessageTag: UInt8 {
    case sendNameTag = 78 // N
    case challengeReply = 114 // r
}

enum ResponseTag: UInt8 {
    case challengeStatus = 115 // s
    case challengeAck = 97 // a
}