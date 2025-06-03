import JavaScriptKit

func _i_need_to_be_here_for_wasm_exports_to_work() {
    _ = _swjs_library_features
    _ = _swjs_call_host_function
    _ = _swjs_free_host_function
}

@_cdecl("strlen")
func strlen(_ s: UnsafePointer<Int8>) -> Int {
    var p = s
    while p.pointee != 0 {
        p += 1
    }
    return p - s
}

@_cdecl("putchar")
public func putchar(_ value: CInt) -> CInt {
    return 0
}

enum LCG {
    nonisolated(unsafe) static var x: UInt8 = 0
    static let a: UInt8 = 0x05
    static let c: UInt8 = 0x0b

    static func next() -> UInt8 {
        x = a &* x &+ c
        return x
    }
}

@_cdecl("arc4random_buf")
public func arc4random_buf(_ buffer: UnsafeMutableRawPointer, _ size: Int) {
    for i in 0..<size {
        buffer.storeBytes(of: LCG.next(), toByteOffset: i, as: UInt8.self)
    }
}