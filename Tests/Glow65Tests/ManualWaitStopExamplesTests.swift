import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// マニュアル 5.7 の WAI と STP の使い方の例が、そのとおり動くことの確認(ボード全体で)。
final class ManualWaitStopExamplesTests: XCTestCase {
    private func machine() throws -> Machine {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../ROM/monitor.bin")
            .standardized
        let monitor = [UInt8](try XCTUnwrap(try? Data(contentsOf: url)))
        let m = Machine(cpuModel: .cmos65C02)
        m.bus.loadROM(monitor, at: 0xF000)
        m.powerOn()
        m.run(cycles: 20_000)                       // モニタが入力待ちになるまで
        return m
    }

    /// `CLI / WAI / INX`: 割り込みが来てハンドラが戻ったあとで、INX が実行される(UART の受信 IRQ)
    func testCliWaitIncrementRunsAfterTheHandlerReturns() throws {
        let m = try machine()
        // ハンドラ($0320): 受信データを読んで要求を下げ、RTI で戻る
        try m.bus.loadRAM([0xAD, 0x01, 0xA0, 0x40], at: 0x0320)               // LDA $A001 / RTI
        try m.bus.loadRAM([0x20, 0x03], at: 0x03FA)                           // IRQ ベクタ = $0320
        try m.bus.loadRAM([0xA2, 0x00, 0xA9, 0x80, 0x8D, 0x00, 0xA0,          // LDX #0 / LDA #$80 / STA $A000
                           0x58, 0xCB, 0xE8, 0x4C, 0x0A, 0x03], at: 0x0300)   // CLI / WAI / INX / JMP $030A
        m.cpu.pc = 0x0300
        m.run(cycles: 200)
        XCTAssertTrue(m.cpu.isWaiting)
        XCTAssertEqual(m.cpu.x, 0, "割り込みが来るまで、INX は実行されない")
        m.run(cycles: 1_000)
        XCTAssertEqual(m.cpu.x, 0, "待っている間は、時間が経っても変わらない")
        m.uart.receive(0x41)
        m.run(cycles: 200)
        XCTAssertFalse(m.cpu.isWaiting)
        XCTAssertEqual(m.cpu.x, 1, "ハンドラが戻ったあとで INX が 1 回実行される")
    }

    /// `LDA #$01 / STA $03F0 / STP`: 書いたあとで止まり、NMI も IRQ も効かず、RESET で再開する
    func testStopHaltsUntilReset() throws {
        let m = try machine()
        try m.bus.loadRAM([0xA2, 0x00, 0xA9, 0x01, 0x8D, 0xF0, 0x03, 0xDB, 0xE8], at: 0x0300)  // LDX #0 / ... / STP / INX
        m.cpu.pc = 0x0300
        m.run(cycles: 200)
        XCTAssertEqual(m.bus.peek(0x03F0), 1)
        XCTAssertTrue(m.cpu.isStopped)
        XCTAssertEqual(m.cpu.x, 0, "STP の次の命令は実行されない")
        m.triggerNMI()
        m.uart.receive(0x41)
        m.run(cycles: 1_000)
        XCTAssertTrue(m.cpu.isStopped, "NMI と IRQ では、再開しない")
        m.reset()
        XCTAssertFalse(m.cpu.isStopped)
        XCTAssertEqual(m.cpu.pc, 0xF12A, "RESET で、リセットベクタから再開する")
    }
}
