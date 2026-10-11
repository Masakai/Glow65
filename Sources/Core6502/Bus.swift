/// 6502 のアドレスバスとデータバスを抽象化したもの。
///
/// CPU はこのプロトコルを通してのみメモリと周辺デバイスにアクセスする。
public protocol Bus: AnyObject {
    func read(_ address: UInt16) -> UInt8
    func write(_ address: UInt16, _ value: UInt8)
}

/// 64KB の単純な RAM。CPU 単体のテスト用。
public final class FlatMemory: Bus {
    public var bytes: [UInt8]

    public init() {
        bytes = [UInt8](repeating: 0, count: 0x10000)
    }

    @inline(__always)
    public func read(_ address: UInt16) -> UInt8 {
        bytes[Int(address)]
    }

    @inline(__always)
    public func write(_ address: UInt16, _ value: UInt8) {
        bytes[Int(address)] = value
    }

    /// 指定アドレスからバイト列を書き込む。
    public func load(_ data: [UInt8], at address: UInt16) {
        for (i, b) in data.enumerated() {
            bytes[(Int(address) + i) & 0xFFFF] = b
        }
    }
}
