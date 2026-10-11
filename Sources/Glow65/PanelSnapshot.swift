import Core6502

/// 動作速度の設定(SPEED スイッチ)。
public enum SpeedSetting: Int, CaseIterable, Sendable {
    case hz1, hz10, hz100, khz1, khz100, mhz1

    /// 1秒あたりのサイクル数。
    public var hertz: Double {
        switch self {
        case .hz1: return 1
        case .hz10: return 10
        case .hz100: return 100
        case .khz1: return 1_000
        case .khz100: return 100_000
        case .mhz1: return 1_000_000
        }
    }

    public var label: String {
        switch self {
        case .hz1: return "1 Hz"
        case .hz10: return "10 Hz"
        case .hz100: return "100 Hz"
        case .khz1: return "1 kHz"
        case .khz100: return "100 kHz"
        case .mhz1: return "1 MHz"
        }
    }

    /// 1サイクルずつ LED に表示できる速度か。それ以上は平均輝度で表示する。
    public var showsEveryCycle: Bool { hertz <= 1_000 }
}

/// フロントパネルに表示する状態の一括コピー。UI スレッドから安全に読める。
public struct PanelSnapshot: Sendable {
    public var isPoweredOn = false
    /// RUN スイッチの状態。false のとき CPU は停止している。
    public var isRunning = false
    public var speed = SpeedSetting.mhz1

    /// アドレス LED(A0...A15 の順)と データ LED(D0...D7)の明るさ(0...1)。
    public var address = [Double](repeating: 0, count: 16)
    public var data = [Double](repeating: 0, count: 8)
    public var readLevel = 0.0
    public var writeLevel = 0.0
    public var syncLevel = 0.0

    public var a: UInt8 = 0
    public var x: UInt8 = 0
    public var y: UInt8 = 0
    public var sp: UInt8 = 0
    public var pc: UInt16 = 0
    public var status: UInt8 = 0
    public var irqLine = false
    public var nmiPending = false

    /// PC の位置の命令(これから、または今実行している命令)。電源が切れていれば nil。
    public var instruction: DisassembledInstruction?

    public var uartTransmitCount: UInt64 = 0
    public var uartReceiveCount: UInt64 = 0
    public var cycles: UInt64 = 0

    public init() {}
}
