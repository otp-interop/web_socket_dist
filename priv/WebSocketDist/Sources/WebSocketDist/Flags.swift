extension Node {
    struct Flags: OptionSet {
        var rawValue: UInt64

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