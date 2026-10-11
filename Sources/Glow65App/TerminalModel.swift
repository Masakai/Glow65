import Foundation
import SwiftUI

/// UART に接続する簡易端末。CR、LF、BS だけを解釈する文字グリッド。
@MainActor
final class TerminalModel: ObservableObject {
    @Published private(set) var text = ""

    private var lines: [[Character]] = [[]]
    private var column = 0
    private let maxLines = 500

    /// エミュレーションスレッドから送られてくるバイトの受け皿(ロック保護)。
    private let inbox = Inbox()

    nonisolated func enqueue(_ byte: UInt8) {
        inbox.append(byte)
    }

    /// 溜まった出力を画面に反映する(メインスレッドから定期的に呼ぶ)。
    func flush() {
        let bytes = inbox.drain()
        guard !bytes.isEmpty else { return }
        for byte in bytes { process(byte) }
        text = lines.map { String($0) }.joined(separator: "\n")
    }

    func clear() {
        lines = [[]]
        column = 0
        text = ""
    }

    private func process(_ byte: UInt8) {
        switch byte {
        case 0x0D:
            column = 0
        case 0x0A:
            lines.append([])
            if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }
            // 改行後の桁は CR で決まる(CR LF の組を想定)。LF のみなら先頭から始める。
            if column > 0 { lines[lines.count - 1] = [Character](repeating: " ", count: column) }
        case 0x08, 0x7F:
            if column > 0 { column -= 1 }
        case 0x20...0x7E:
            var line = lines[lines.count - 1]
            if column < line.count {
                line[column] = Character(UnicodeScalar(byte))
            } else {
                line.append(Character(UnicodeScalar(byte)))
            }
            lines[lines.count - 1] = line
            column += 1
        default:
            break
        }
    }

    private final class Inbox: @unchecked Sendable {
        private var buffer: [UInt8] = []
        private let lock = NSLock()

        func append(_ byte: UInt8) {
            lock.lock()
            buffer.append(byte)
            lock.unlock()
        }

        func drain() -> [UInt8] {
            lock.lock()
            defer { lock.unlock() }
            let out = buffer
            buffer.removeAll(keepingCapacity: true)
            return out
        }
    }
}
