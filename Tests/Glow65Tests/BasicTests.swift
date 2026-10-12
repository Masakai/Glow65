import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// Microsoft BASIC(ROM/basic でビルドしたもの)を本ボード上で動かす統合テスト。
final class BasicTests: XCTestCase {
    final class Output {
        var bytes: [UInt8] = []
        var text: String { String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\r", with: "") }
    }

    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    }

    private func makeMachine() throws -> (Machine, Output) {
        let monitor = root().appendingPathComponent("ROM/monitor.bin")
        let basic = root().appendingPathComponent("ROM/basic/build/basic.bin")
        guard let mon = try? Data(contentsOf: monitor), let bas = try? Data(contentsOf: basic) else {
            throw XCTSkip("monitor.bin または basic.bin がない。Tools/build_monitor.sh と Tools/build_basic.sh を実行する")
        }
        let machine = Machine()
        machine.bus.loadROM([UInt8](bas), at: 0xC000)
        machine.bus.loadROM([UInt8](mon), at: 0xF000)
        let out = Output()
        machine.uart.onTransmit = { out.bytes.append($0) }
        machine.powerOn()
        return (machine, out)
    }

    private func send(_ m: Machine, _ text: String, cycles: Int = 3_000_000) {
        for b in text.utf8 { m.uart.receive(b) }
        m.run(cycles: cycles)
    }

    /// 起動して BASIC の `OK` プロンプトまで進める。
    private func bootBasic() throws -> (Machine, Output) {
        let (m, out) = try makeMachine()
        m.run(cycles: 50_000)
        send(m, "b\r", cycles: 200_000)         // モニタから BASIC を起動
        send(m, "\r", cycles: 5_000_000)        // MEMORY SIZE? → 自動検出
        send(m, "\r", cycles: 500_000)          // TERMINAL WIDTH? → 既定
        return (m, out)
    }

    func testBootsToOK() throws {
        let (_, out) = try bootBasic()
        XCTAssertTrue(out.text.contains("MEMORY SIZE"), out.text)
        XCTAssertTrue(out.text.contains("BYTES FREE"), out.text)
        XCTAssertTrue(out.text.contains("OK"), out.text)
        // 起動バナー: 機種名は差し替え、Microsoft の著作権表示は残す
        XCTAssertTrue(out.text.contains("GLOW65 BASIC  (MICROSOFT BASIC V1.1 FOR 6502)"), out.text)
        XCTAssertTrue(out.text.contains("COPYRIGHT 1978 MICROSOFT"), out.text)
        XCTAssertFalse(out.text.contains("OSI"), out.text)
    }

    /// 小文字で打った予約語と変数名は大文字になり、引用符・REM・DATA の中はそのまま残る。
    func testLowercaseInputIsUppercased() throws {
        let (m, out) = try bootBasic()
        for line in ["10 for i=1 to 2: print i; \"hello\"", "20 next i", "30 rem lower stays", "40 data abc", "50 read a$: print a$"] {
            send(m, line + "\r", cycles: 300_000)
        }
        out.bytes.removeAll()
        send(m, "run\r", cycles: 2_000_000)
        XCTAssertTrue(out.text.contains(" 1 hello"), out.text)
        XCTAssertTrue(out.text.contains(" 2 hello"), out.text)
        XCTAssertTrue(out.text.contains("abc"), out.text)
        XCTAssertFalse(out.text.contains("SYNTAX"), out.text)
        out.bytes.removeAll()
        send(m, "list\r", cycles: 2_000_000)
        XCTAssertTrue(out.text.contains("10 FOR I=1 TO 2: PRINT I; \"hello\""), out.text)
        XCTAssertTrue(out.text.contains("30 REM lower stays"), out.text)
        XCTAssertTrue(out.text.contains("40 DATA abc"), out.text)
        XCTAssertTrue(out.text.contains("50 READ A$: PRINT A$"), out.text)
    }

    func testPrintArithmetic() throws {
        let (m, out) = try bootBasic()
        out.bytes.removeAll()
        send(m, "PRINT 1+1\r")
        XCTAssertTrue(out.text.contains(" 2"), out.text)
        out.bytes.removeAll()
        send(m, "PRINT 355/113\r")
        XCTAssertTrue(out.text.contains("3.14159"), out.text)
    }

    func testProgramWithLoop() throws {
        let (m, out) = try bootBasic()
        out.bytes.removeAll()
        send(m, "10 S=0\r20 FOR I=1 TO 100\r30 S=S+I\r40 NEXT I\r50 PRINT S\rRUN\r", cycles: 8_000_000)
        XCTAssertTrue(out.text.contains(" 5050"), out.text)
    }

    func testStringsAndFunctions() throws {
        let (m, out) = try bootBasic()
        out.bytes.removeAll()
        send(m, "PRINT LEFT$(\"HELLO\",2);CHR$(65);LEN(\"ABC\")\r", cycles: 1_000_000)
        XCTAssertTrue(out.text.contains("HEA 3"), out.text)
        out.bytes.removeAll()
        send(m, "PRINT SQR(16);SIN(0);INT(-2.5)\r", cycles: 3_000_000)
        XCTAssertTrue(out.text.contains(" 4  0 -3"), out.text)
    }

    func testPeekPokeAndErrors() throws {
        let (m, out) = try bootBasic()
        out.bytes.removeAll()
        send(m, "POKE 2000,77:PRINT PEEK(2000)\r", cycles: 1_000_000)
        XCTAssertEqual(m.bus.ram[2000], 77)
        XCTAssertTrue(out.text.contains(" 77"), out.text)
        out.bytes.removeAll()
        send(m, "PRINT 1/0\r", cycles: 3_000_000)
        XCTAssertTrue(out.text.contains("?DIVISION BY ZERO ERROR"), out.text)
    }

    func testArraysGosubDataAndStringChurn() throws {
        let (m, out) = try bootBasic()
        out.bytes.removeAll()
        let program = [
            "10 DIM A(10)",
            "20 FOR I=0 TO 10:A(I)=I*I:NEXT",
            "30 S$=\"\":FOR I=1 TO 50:S$=S$+\"X\":NEXT",
            "40 PRINT A(10);LEN(S$)",
            "50 GOSUB 100:PRINT \"DONE\"",
            "60 FOR I=1 TO 400:B$=STR$(I)+\"ABCDEFGHIJ\":NEXT",
            "70 PRINT B$",
            "80 END",
            "100 READ X:PRINT X:RETURN",
            "110 DATA 42",
            "RUN",
        ].joined(separator: "\r") + "\r"
        send(m, program, cycles: 40_000_000)
        XCTAssertTrue(out.text.contains(" 100  50"), out.text)
        XCTAssertTrue(out.text.contains(" 42"), out.text)
        XCTAssertTrue(out.text.contains("DONE"), out.text)
        XCTAssertTrue(out.text.contains(" 400ABCDEFGHIJ"), out.text)
    }
}
