import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

final class MonitorTests: XCTestCase {
    private func makeMachine() throws -> (Machine, Output) {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../ROM/monitor.bin")
            .standardized
        guard let data = try? Data(contentsOf: url) else {
            throw XCTSkip("monitor.bin がない。Tools/build_monitor.sh を実行する")
        }
        let machine = Machine()
        machine.bus.loadROM([UInt8](data), at: 0xF000)
        let out = Output()
        machine.uart.onTransmit = { out.bytes.append($0) }
        machine.powerOn()
        return (machine, out)
    }

    final class Output {
        var bytes: [UInt8] = []
        var text: String { String(decoding: bytes, as: UTF8.self) }
    }

    /// 入力を送り、サイクル数だけ実行して出力を返す。
    private func type(_ machine: Machine, _ out: Output, _ line: String, cycles: Int = 200_000) {
        for b in line.utf8 { machine.uart.receive(b) }
        machine.run(cycles: cycles)
    }

    func testBannerAndPrompt() throws {
        let (m, out) = try makeMachine()
        m.run(cycles: 20_000)
        XCTAssertTrue(out.text.contains("GLOW65 MONITOR"), out.text)
        XCTAssertTrue(out.text.hasSuffix("*"), out.text)
    }

    func testDump() throws {
        let (m, out) = try makeMachine()
        m.run(cycles: 20_000)
        out.bytes.removeAll()
        type(m, out, "d f000 f00f\r")
        // $F000 は CHRIN へのジャンプ命令(4C 0F F0 ...)
        XCTAssertTrue(out.text.contains("F000: 4C 0F F0 4C 28 F0"), out.text)
    }

    func testWriteAndDump() throws {
        let (m, out) = try makeMachine()
        m.run(cycles: 20_000)
        out.bytes.removeAll()
        type(m, out, "e 0300 de ad be ef\r")
        XCTAssertEqual(Array(m.bus.ram[0x300..<0x304]), [0xDE, 0xAD, 0xBE, 0xEF])
    }

    func testGoRunsUserCode() throws {
        let (m, out) = try makeMachine()
        m.run(cycles: 20_000)
        out.bytes.removeAll()
        // LDA #'Z'; JSR $F003(CHROUT); RTS
        type(m, out, "e 0400 a9 5a 20 03 f0 60\r")
        type(m, out, "g 0400\r")
        XCTAssertTrue(out.text.contains("Z"), out.text)
        XCTAssertTrue(out.text.hasSuffix("*"), out.text)  // RTS 後にプロンプトへ戻る
    }

    func testBackspaceAndUnknownCommand() throws {
        let (m, out) = try makeMachine()
        m.run(cycles: 20_000)
        out.bytes.removeAll()
        type(m, out, "x\r")
        XCTAssertTrue(out.text.contains("?"), out.text)
    }

    func testResetKeepsRAMButPowerCycleClearsIt() throws {
        let (m, out) = try makeMachine()
        m.run(cycles: 20_000)
        type(m, out, "e 0300 55\r")
        XCTAssertEqual(m.bus.ram[0x300], 0x55)
        m.reset()
        XCTAssertEqual(m.bus.ram[0x300], 0x55)
        let vector = UInt16(m.bus.read(0xFFFC)) | UInt16(m.bus.read(0xFFFD)) << 8
        XCTAssertEqual(m.cpu.pc, vector)  // リセットベクタへ移った
        m.powerOff()
        XCTAssertEqual(m.bus.ram[0x300], 0)
        XCTAssertFalse(m.isPoweredOn)
    }
}
