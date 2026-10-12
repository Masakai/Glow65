import Foundation

/// MC6850 ACIA 風の最小 UART(状態/制御と送受信データのみ)。
///
/// - `$A000` 読み出し: 状態。bit0 = RDRF(受信データあり)、bit1 = TDRE(送信可)、bit7 = IRQ(割り込み要求中)。
/// - `$A000` 書き込み: 制御。下位2ビットが `11` ならマスタリセット(受信キューを空にし、割り込み許可も切る)。
///   bit7 = 受信割り込み許可(RIE)。1 で、受信データがある間 IRQ 線を出す(レベルトリガ)。
///   要求は `$A001` を読んで受信キューを空にすると下がる。
/// - `$A001` 読み出し: 受信データ。 `$A001` 書き込み: 送信データ。
///
/// ホスト側(別スレッド)から `receive` を呼べるよう、受信キューはロックで保護する。
public final class UART {
    public static let statusReceiveReady: UInt8 = 0x01
    public static let statusTransmitEmpty: UInt8 = 0x02
    public static let statusInterrupt: UInt8 = 0x80
    public static let controlReceiveInterruptEnable: UInt8 = 0x80

    /// CPU が送信データを書き込んだときに呼ばれる(エミュレーションスレッド上)。
    public var onTransmit: ((UInt8) -> Void)?

    /// LED 表示用の活動カウンタ(送信/受信が起きるたびに増える)。
    public private(set) var transmitCount: UInt64 = 0
    public private(set) var receiveCount: UInt64 = 0

    private var queue: [UInt8] = []
    private var control: UInt8 = 0
    private let lock = NSLock()

    public init() {}

    /// ホストから CPU へ1バイト送る。どのスレッドからでも呼べる。
    public func receive(_ byte: UInt8) {
        lock.lock()
        queue.append(byte)
        lock.unlock()
    }

    /// 受信キューの未読バイト数。
    public var pendingReceiveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }

    /// IRQ 線の状態。受信割り込みが許可されていて、未読の受信データがある間 true。
    public var interruptRequest: Bool {
        lock.lock()
        defer { lock.unlock() }
        return control & Self.controlReceiveInterruptEnable != 0 && !queue.isEmpty
    }

    func readStatus() -> UInt8 {
        lock.lock()
        let hasData = !queue.isEmpty
        let irq = hasData && control & Self.controlReceiveInterruptEnable != 0
        lock.unlock()
        return (hasData ? Self.statusReceiveReady : 0) | Self.statusTransmitEmpty
            | (irq ? Self.statusInterrupt : 0)
    }

    func readData() -> UInt8 {
        lock.lock()
        defer { lock.unlock() }
        guard !queue.isEmpty else { return 0 }
        receiveCount &+= 1
        return queue.removeFirst()
    }

    func writeControl(_ value: UInt8) {
        lock.lock()
        if value & 0x03 == 0x03 {
            queue.removeAll()
            control = 0
        } else {
            control = value
        }
        lock.unlock()
    }

    func writeData(_ value: UInt8) {
        transmitCount &+= 1
        onTransmit?(value)
    }

    /// 電源断などで状態を初期化する。
    public func reset() {
        lock.lock()
        queue.removeAll()
        control = 0
        lock.unlock()
    }
}
