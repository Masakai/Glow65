import Foundation

/// MC6850 ACIA 風の最小 UART(状態/制御と送受信データのみ)。
///
/// - `$A000` 読み出し: 状態。bit0 = RDRF(受信データあり)、bit1 = TDRE(送信可)。
/// - `$A000` 書き込み: 制御。下位2ビットが `11` ならマスタリセット(受信キューを空にする)。
/// - `$A001` 読み出し: 受信データ。 `$A001` 書き込み: 送信データ。
///
/// ホスト側(別スレッド)から `receive` を呼べるよう、受信キューはロックで保護する。
public final class UART {
    public static let statusReceiveReady: UInt8 = 0x01
    public static let statusTransmitEmpty: UInt8 = 0x02

    /// CPU が送信データを書き込んだときに呼ばれる(エミュレーションスレッド上)。
    public var onTransmit: ((UInt8) -> Void)?

    /// LED 表示用の活動カウンタ(送信/受信が起きるたびに増える)。
    public private(set) var transmitCount: UInt64 = 0
    public private(set) var receiveCount: UInt64 = 0

    private var queue: [UInt8] = []
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

    func readStatus() -> UInt8 {
        lock.lock()
        let hasData = !queue.isEmpty
        lock.unlock()
        return (hasData ? Self.statusReceiveReady : 0) | Self.statusTransmitEmpty
    }

    func readData() -> UInt8 {
        lock.lock()
        defer { lock.unlock() }
        guard !queue.isEmpty else { return 0 }
        receiveCount &+= 1
        return queue.removeFirst()
    }

    func writeControl(_ value: UInt8) {
        if value & 0x03 == 0x03 {
            lock.lock()
            queue.removeAll()
            lock.unlock()
        }
    }

    func writeData(_ value: UInt8) {
        transmitCount &+= 1
        onTransmit?(value)
    }

    /// 電源断などで状態を初期化する。
    public func reset() {
        lock.lock()
        queue.removeAll()
        lock.unlock()
    }
}
