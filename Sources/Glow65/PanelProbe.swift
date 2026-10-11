/// CPU のバスアクセス1回分(1サイクル相当)。
public struct BusAccess: Equatable {
    public var address: UInt16
    public var data: UInt8
    public var isWrite: Bool
    /// 命令フェッチ(SYNC)かどうか。
    public var isSync: Bool
}

/// バスの動きを監視し、フロントパネルの LED 表示に必要な情報を集める。
///
/// 高速実行では、各ビットが「1だったアクセスの割合」を積算して平均輝度にする。
/// 低速実行・ステップ実行では、アクセスを時系列で記録して1サイクルずつ再生する。
/// エミュレーションスレッドからのみ操作する。
public final class PanelProbe {
    /// 積算結果。`takeLevels()` で取り出すと積算はリセットされる。
    public struct Levels {
        public var address = [Double](repeating: 0, count: 16)
        public var data = [Double](repeating: 0, count: 8)
        public var read = 0.0
        public var write = 0.0
        public var sync = 0.0
        public var accessCount = 0
    }

    /// 平均輝度の積算を行うか(高速実行時のみ有効にする)。
    public var accumulatesGlow = true
    /// アクセスの時系列を記録するか(低速・ステップ実行時のみ有効にする)。
    public var recordsAccesses = false
    /// 直前の命令が次に起こす最初のアクセスを SYNC として扱う。
    public var syncPending = false

    public private(set) var lastAccess = BusAccess(address: 0, data: 0, isWrite: false, isSync: false)
    public private(set) var accesses: [BusAccess] = []

    private var addressOn = [UInt32](repeating: 0, count: 16)
    private var dataOn = [UInt32](repeating: 0, count: 8)
    private var total: UInt32 = 0
    private var writes: UInt32 = 0
    private var syncs: UInt32 = 0

    public init() {}

    @inline(__always)
    func record(address: UInt16, data: UInt8, isWrite: Bool) {
        let sync = syncPending
        syncPending = false
        lastAccess = BusAccess(address: address, data: data, isWrite: isWrite, isSync: sync)
        if recordsAccesses {
            accesses.append(lastAccess)
        }
        guard accumulatesGlow else { return }
        total &+= 1
        if isWrite { writes &+= 1 }
        if sync { syncs &+= 1 }
        var a = address
        while a != 0 {
            addressOn[a.trailingZeroBitCount] &+= 1
            a &= a &- 1
        }
        var d = data
        while d != 0 {
            dataOn[d.trailingZeroBitCount] &+= 1
            d &= d &- 1
        }
    }

    /// 記録済みのアクセス列を空にする。
    public func clearAccesses() {
        accesses.removeAll(keepingCapacity: true)
    }

    /// 積算した平均輝度を取り出し、積算をリセットする。
    public func takeLevels() -> Levels {
        var levels = Levels()
        levels.accessCount = Int(total)
        if total > 0 {
            let n = Double(total)
            for i in 0..<16 { levels.address[i] = Double(addressOn[i]) / n }
            for i in 0..<8 { levels.data[i] = Double(dataOn[i]) / n }
            levels.write = Double(writes) / n
            levels.read = 1 - levels.write
            levels.sync = Double(syncs) / n
        }
        for i in 0..<16 { addressOn[i] = 0 }
        for i in 0..<8 { dataOn[i] = 0 }
        total = 0
        writes = 0
        syncs = 0
        return levels
    }
}
