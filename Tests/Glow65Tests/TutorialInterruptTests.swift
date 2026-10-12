import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// tutorial/ の第 6 章(割り込み)の内容が、実際の動作と一致することを確かめる。
final class TutorialInterruptTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    }

    private func program(_ name: String) throws -> [UInt8] {
        let data = try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("tutorial/\(name).bin")), "\(name).bin がない")
        return [UInt8](data)
    }

    private final class Console {
        let machine = Machine()
        var bytes: [UInt8] = []
        init(root: URL) throws {
            let monitor = try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("ROM/monitor.bin")))
            machine.bus.loadROM([UInt8](monitor), at: 0xF000)
            machine.uart.onTransmit = { [unowned self] in self.bytes.append($0) }
            machine.powerOn()
            machine.run(cycles: 20_000)
        }
        var text: String { String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\r", with: "") }
        func type(_ s: String, cycles: Int = 400_000) {
            bytes.removeAll()
            for b in s.utf8 { machine.uart.receive(b) }
            machine.run(cycles: cycles)
        }
    }

    // MARK: UART の割り込み要求

    func testUARTInterruptRequestFollowsEnableAndQueue() {
        let uart = UART()
        uart.receive(0x41)
        XCTAssertFalse(uart.interruptRequest)                      // 許可していなければ出さない
        XCTAssertEqual(uart.readStatus() & 0x80, 0)
        uart.writeControl(0x80)
        XCTAssertTrue(uart.interruptRequest)
        XCTAssertEqual(uart.readStatus(), 0x83)                    // IRQ + TDRE + RDRF
        XCTAssertEqual(uart.readData(), 0x41)                      // データを読むと下がる
        XCTAssertFalse(uart.interruptRequest)
        XCTAssertEqual(uart.readStatus(), 0x02)
        uart.receive(0x42)
        XCTAssertTrue(uart.interruptRequest)
        uart.writeControl(0x03)                                    // マスタリセットで許可も消える
        XCTAssertFalse(uart.interruptRequest)
        uart.receive(0x43)
        XCTAssertFalse(uart.interruptRequest)
    }

    // MARK: モニタの既定動作

    func testMonitorInstallsReturnOnlyVectors() throws {
        let c = try Console(root: root)
        let rti = UInt16(c.machine.bus.peek(0x03F8)) | UInt16(c.machine.bus.peek(0x03F9)) << 8
        XCTAssertEqual(rti, UInt16(c.machine.bus.peek(0x03FA)) | UInt16(c.machine.bus.peek(0x03FB)) << 8)
        XCTAssertEqual(c.machine.bus.peek(rti), 0x40)              // RTI
    }

    func testNMIWithDefaultVectorDoesNotDisturbMonitor() throws {
        let c = try Console(root: root)
        c.machine.triggerNMI()
        c.type("d f000 f000\r")
        XCTAssertTrue(c.text.contains("F000:"), c.text)
    }

    // MARK: nmi_count

    func testNMICountSample() throws {
        XCTAssertEqual(try program("nmi_count").count, 36)
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("nmi_count"), at: 0x0300)
        c.type("g 0300\r")
        XCTAssertEqual(c.machine.bus.peek(0x03F0), 0)
        c.bytes.removeAll()
        for _ in 0..<3 {
            c.machine.triggerNMI()
            c.machine.run(cycles: 2_000)
        }
        XCTAssertEqual(c.machine.bus.peek(0x03F0), 3)
        XCTAssertEqual(c.text, "!!!")
    }

    /// 手順書: 割り込みの受付は、PCH・PCL・P をスタックに積んでから NMI ベクタ($FFFA)を読む
    func testNMIEntryBusAccesses() throws {
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("nmi_count"), at: 0x0300)
        c.type("g 0300\r")
        let probe = PanelProbe()
        probe.recordsAccesses = true
        c.machine.bus.probe = probe
        let spBefore = c.machine.cpu.sp
        let pcBefore = c.machine.cpu.pc
        c.machine.triggerNMI()
        c.machine.step()
        let a = probe.accesses
        let writes = a.filter { $0.isWrite }
        XCTAssertEqual(writes.map(\.address), [0x0100 | UInt16(spBefore), 0x0100 | UInt16(spBefore &- 1), 0x0100 | UInt16(spBefore &- 2)])
        XCTAssertEqual(writes[0].data, UInt8(pcBefore >> 8))
        XCTAssertEqual(writes[1].data, UInt8(pcBefore & 0xFF))
        // 手順書の表の値が、モニタ ROM の実際のベクタと一致すること(ROM の配置が動くと値が変わる)
        let lo = try XCTUnwrap(a.first { $0.address == 0xFFFA && !$0.isWrite }).data
        let hi = try XCTUnwrap(a.first { $0.address == 0xFFFB && !$0.isWrite }).data
        for chapter in ["tutorial/06-interrupts.md", "tutorial/06-interrupts.ja.md"] {
            let text = try String(contentsOf: root.appendingPathComponent(chapter), encoding: .utf8)
            XCTAssertTrue(text.contains(String(format: "| `$FFFA` | `%02X` |", lo)), "\(chapter): $FFFA")
            XCTAssertTrue(text.contains(String(format: "| `$FFFB` | `%02X` |", hi)), "\(chapter): $FFFB")
        }
        XCTAssertTrue(a.contains { $0.address == 0xFFFA && !$0.isWrite })
        XCTAssertTrue(a.contains { $0.address == 0xFFFB && !$0.isWrite })
        XCTAssertFalse(a.contains { $0.isSync && $0.address < 0x0300 && $0.address >= 0x0100 })
        XCTAssertNotEqual(c.machine.cpu.p & CPU6502.Flag.interruptDisable, 0)   // 受付後は I が立つ
    }

    // MARK: irq_echo

    func testIRQEchoSample() throws {
        XCTAssertEqual(try program("irq_echo").count, 85)
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("irq_echo"), at: 0x0300)
        c.type("g 0300\r")
        c.machine.run(cycles: 50_000)                              // 入力がなくても数えている
        let early = Int(c.machine.bus.peek(0x03F0)) | Int(c.machine.bus.peek(0x03F1)) << 8
        XCTAssertGreaterThan(early, 100)
        c.type("Hi!")
        XCTAssertEqual(c.text, "Hi!")                              // 割り込みでエコーされる
        c.type("\r")
        XCTAssertEqual(c.text, "\n*")
        XCTAssertEqual(c.machine.bus.peek(0x03F2), 0x0D)
        XCTAssertFalse(c.machine.uart.interruptRequest)
        c.type("d f000 f000\r")                                    // モニタが普通に使える(ポーリングに戻った)
        XCTAssertTrue(c.text.contains("F000:"), c.text)
    }

    /// 割り込みを許可したまま RTS で戻っても、モニタのウォームスタートが UART の割り込みを切る
    func testWarmStartDisablesUARTInterrupt() throws {
        let c = try Console(root: root)
        c.type("e 0300 a9 80 8d 00 a0 58 60\rg 0300\r")           // lda #$80 / sta $A000 / cli / rts
        c.type("x")
        XCTAssertFalse(c.machine.uart.interruptRequest)
    }

    /// 練習: IRQ を許可して RTI だけのハンドラだと、受信データを読まないので要求が下がらず、ずっと割り込み直す
    func testIRQWithoutAcknowledgeNeverLeavesTheHandler() throws {
        let c = try Console(root: root)
        c.type("e 0300 a9 80 8d 00 a0 58 4c 06 03\rg 0300\r")   // lda #$80 / sta $A000 / cli / jmp $0306
        for _ in 0..<1000 { c.machine.step() }
        XCTAssertTrue((0x0300...0x030A).contains(c.machine.cpu.pc))   // まだ主プログラムが動いている
        c.machine.uart.receive(0x78)
        for _ in 0..<1000 { c.machine.step() }
        XCTAssertEqual(c.machine.uart.pendingReceiveCount, 1)            // 読まれないまま
        XCTAssertTrue(c.machine.uart.interruptRequest)
        var mainSteps = 0
        for _ in 0..<1000 {
            c.machine.step()
            if (0x0300...0x030A).contains(c.machine.cpu.pc) { mainSteps += 1 }
        }
        XCTAssertLessThan(mainSteps, 400)                                 // 3 ステップに 1 回、RTI で戻った直後に PC が主プログラムにあるだけ(命令は実行されない)
    }

    /// 練習: BRK は IRQ と同じベクタを使い、BRK の次のバイト(署名)を飛ばして戻る
    func testBRKUsesTheIRQVectorAndSkipsOneByte() throws {
        let c = try Console(root: root)
        c.type("e 0300 a9 01 00 60 8d f0 03 60\rg 0300\r")
        XCTAssertEqual(c.machine.bus.peek(0x03F0), 1)
        XCTAssertTrue(c.text.hasSuffix("*"), c.text)
    }
}
