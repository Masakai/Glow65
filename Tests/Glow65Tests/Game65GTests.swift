import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// GAME65G(ROM/game65g.bin)を本ボード上で動かす統合テスト。NMOS 6502 と 65C02 の両方で確かめる。
final class Game65GTests: XCTestCase {
    final class Output {
        var bytes: [UInt8] = []
        var text: String { String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\r", with: "") }
    }

    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    }

    private func makeMachine(_ model: CPUModel) throws -> (Machine, Output) {
        guard let mon = try? Data(contentsOf: root().appendingPathComponent("ROM/monitor.bin")),
              let game = try? Data(contentsOf: root().appendingPathComponent("ROM/game65g.bin")) else {
            throw XCTSkip("monitor.bin または game65g.bin がない。Tools/build_monitor.sh と Tools/build_game65g.sh を実行する")
        }
        let machine = Machine(cpuModel: model)
        machine.bus.loadROM([UInt8](mon), at: 0xF000)
        machine.bus.loadROM([UInt8](game), at: 0x8000)
        let out = Output()
        machine.uart.onTransmit = { out.bytes.append($0) }
        machine.powerOn()
        return (machine, out)
    }

    private func send(_ m: Machine, _ text: String, cycles: Int = 2_000_000) {
        for b in text.utf8 { m.uart.receive(b) }
        m.run(cycles: cycles)
    }

    /// モニタの T で起動し、プロンプトまで進める。
    private func boot(_ model: CPUModel) throws -> (Machine, Output) {
        let (m, out) = try makeMachine(model)
        m.run(cycles: 50_000)
        send(m, "t\r", cycles: 200_000)
        return (m, out)
    }

    /// 行を1行ずつ送り、最後に送った行のあとの出力を返す。
    private func run(_ lines: [String], model: CPUModel, cycles: Int = 2_000_000) throws -> String {
        let (m, out) = try boot(model)
        for line in lines.dropLast() {
            send(m, line + "\r", cycles: 300_000)
        }
        out.bytes.removeAll()
        send(m, lines.last! + "\r", cycles: cycles)
        return out.text
    }

    /// 両方の CPU で同じ結果になることを確かめる。
    private func expect(_ lines: [String], _ expected: String, cycles: Int = 2_000_000,
                        file: StaticString = #filePath, line: UInt = #line) throws {
        for model in [CPUModel.nmos6502, .cmos65C02] {
            let text = try run(lines, model: model, cycles: cycles)
            XCTAssertEqual(text, expected, "\(model)", file: file, line: line)
        }
    }

    func testBannerAndPrompt() throws {
        let (_, out) = try boot(.nmos6502)
        XCTAssertTrue(out.text.contains("GAME65G V1.0\nBASED ON GAME LANGUAGE (ASCII 1978)\n>"), out.text)
    }

    func testMonitorHelpListsT() throws {
        let (m, out) = try makeMachine(.nmos6502)
        m.run(cycles: 50_000)
        send(m, "?\r", cycles: 200_000)
        XCTAssertTrue(out.text.contains("T              GAME65G"), out.text)
    }

    /// $8000-$9FFF は ROM として読め、書き込みは無視される。
    func testGameROMIsReadOnly() throws {
        let (m, _) = try makeMachine(.nmos6502)
        XCTAssertEqual(m.bus.peek(0x8000), 0x4C)       // JMP COLD
        m.bus.write(0x8000, 0x00)
        XCTAssertEqual(m.bus.read(0x8000), 0x4C)
        XCTAssertEqual(m.bus.read(0xA100), 0xFF)       // 未接続のまま
        XCTAssertEqual(m.bus.read(0xBFFF), 0xFF)
    }

    /// GAME65G の ROM があっても、BASIC の RAM 自動検出は $7FFF までで止まる(ROM なしと同じ値)。
    func testBasicMemorySizeIsUnchanged() throws {
        guard let bas = try? Data(contentsOf: root().appendingPathComponent("ROM/basic/build/basic.bin")) else {
            throw XCTSkip("basic.bin がない。Tools/build_basic.sh を実行する")
        }
        func bytesFree(withGame: Bool) throws -> String {
            let (m, out) = try makeMachine(.nmos6502)
            m.bus.loadROM([UInt8](bas), at: 0xC000)
            if !withGame {
                m.bus.loadROM([UInt8](repeating: 0xFF, count: MemoryMap.gameROMSize), at: 0x8000)
            }
            m.run(cycles: 50_000)
            send(m, "b\r", cycles: 200_000)
            send(m, "\r", cycles: 5_000_000)
            send(m, "\r", cycles: 500_000)
            let line = out.text.split(separator: "\n").first { $0.contains("BYTES FREE") }
            return String(line ?? "")
        }
        let without = try bytesFree(withGame: false)
        XCTAssertFalse(without.isEmpty)
        XCTAssertEqual(try bytesFree(withGame: true), without)
    }

    // MARK: 出力

    func testPrintDecimalLeftAndRight() throws {
        try expect(["?=1234 ?=-5 ?(6)=42 ?(2)=1234"], "?=1234 ?=-5 ?(6)=42 ?(2)=1234\n1234-5    421234\n>")
    }

    func testPrintHexCharSpacesStringsAndNewline() throws {
        try expect(["??=$1841 ?$=$1841 $=65 .=3 \"AB\"/\"CD\"//"],
                   "??=$1841 ?$=$1841 $=65 .=3 \"AB\"/\"CD\"//\n184141A   AB\nCD\n\n>")
    }

    func testExtremeValues() throws {
        try expect(["?=-32768 / ?=32767+1 / ?=$FFFF"], "?=-32768 / ?=32767+1 / ?=$FFFF\n-32768\n-32768\n-1\n>")
    }

    // MARK: 式

    func testLeftToRightWithoutPrecedence() throws {
        try expect(["?=2+3*4 / ?=2+(3*4)"], "?=2+3*4 / ?=2+(3*4)\n20\n14\n>")
    }

    func testDivisionAndRemainder() throws {
        try expect(["?=17/5 / ?=%1 / ?=-17/5 / ?=%(-17/5) / ?=17/-5"],
                   "?=17/5 / ?=%1 / ?=-17/5 / ?=%(-17/5) / ?=17/-5\n3\n2\n-3\n-2\n-3\n>")
    }

    func testComparisonsAreSigned() throws {
        try expect(["?=(1<2) ?=(2<1) ?=(-1<1) ?=(3=3) ?=(3<>3) ?=(2<=2) ?=(3>=4) ?=(5>4)"],
                   "?=(1<2) ?=(2<1) ?=(-1<1) ?=(3=3) ?=(3<>3) ?=(2<=2) ?=(3>=4) ?=(5>4)\n10110101\n>")
    }

    func testBitwiseOperators() throws {
        try expect(["??=$F0F0&$0FF0 / ??=$F000.$000F / ??=$FFFF!$8080"],
                   "??=$F0F0&$0FF0 / ??=$F000.$000F / ??=$FFFF!$8080\n00F0\nF00F\n7F7F\n>")
    }

    func testVariablesIgnoreLaterLettersAndLowercase() throws {
        try expect(["alpha=7 ?=A+ab"], "alpha=7 ?=A+ab\n14\n>")
    }

    func testDivideByZeroIsAnError() throws {
        try expect(["?=1/0"], "?=1/0\nERR\n>")
    }

    // MARK: 配列とメモリ

    func testArrays() throws {
        try expect(["A=$3000 A(0)=$1234 A(1)=-2 ?$=A:0) ?$=A:1) ?=A(1) B=$3010 B:2)=65 $=B:2)"],
                   "A=$3000 A(0)=$1234 A(1)=-2 ?$=A:0) ?$=A:1) ?=A(1) B=$3010 B:2)=65 $=B:2)\n3412-2A\n>")
    }

    // MARK: プログラム

    func testEnterListRunAndDelete() throws {
        let (m, out) = try boot(.nmos6502)
        send(m, "20 ?=2\r", cycles: 300_000)
        send(m, "10 ?=1\r", cycles: 300_000)
        send(m, "30 ?=3\r", cycles: 300_000)
        send(m, "20 ?=22\r", cycles: 300_000)   // 置き換え
        out.bytes.removeAll()
        send(m, "0\r")
        XCTAssertEqual(out.text, "0\n10 ?=1\n20 ?=22\n30 ?=3\n>")
        out.bytes.removeAll()
        send(m, "20/\r")
        XCTAssertEqual(out.text, "20/\n20 ?=22\n30 ?=3\n>")
        out.bytes.removeAll()
        send(m, "#=1\r")
        XCTAssertEqual(out.text, "#=1\n1223\n>")
        send(m, "20\r", cycles: 300_000)          // 削除
        out.bytes.removeAll()
        send(m, "0\r")
        XCTAssertEqual(out.text, "0\n10 ?=1\n30 ?=3\n>")
    }

    func testCommentLineIsSkippedAndKeepsCase() throws {
        try expect(["10REM Hello", "20 ?=5", "0", "#=1"], "#=1\n5\n>")
        let text = try run(["10REM Hello", "0"], model: .nmos6502)
        XCTAssertEqual(text, "0\n10REM Hello\n>")
    }

    func testForNextLoop() throws {
        try expect(["10 I=1,5 ?=I @=I+1", "20 / \"END\"", "#=1"], "#=1\n12345\nEND\n>")
    }

    func testForWithNegativeRange() throws {
        try expect(["10 I=-2,2 ?=I .=1 @=I+1", "#=1"], "#=1\n-2 -1 0 1 2 \n>")
    }

    func testDoUntilLoop() throws {
        try expect(["10 K=0 @ K=K+3 @=(K>10)", "20 ?=K", "#=1"], "#=1\n12\n>")
    }

    func testNestedLoops() throws {
        try expect(["10 I=1,3 J=1,2 ?=I*10+J .=1 @=J+1 @=I+1", "#=1"], "#=1\n11 12 21 22 31 32 \n>")
    }

    func testGotoIfGosubReturnAndEnd() throws {
        try expect([
            "10 N=0",
            "20 !=100",
            "30 ;=N<3 #=20",
            "40 \"DONE\" #=-1",
            "50 \"NOT REACHED\"",
            "100 N=N+1 ?=N ]",
            "#=1",
        ], "#=1\n123DONE\n>")
    }

    func testGotoMissingLineGoesToNextLarger() throws {
        try expect(["10 ?=1", "30 ?=3", "#=20"], "#=20\n3\n>")
    }

    func testIfFalseInDirectModeEndsLine() throws {
        try expect([";=0 ?=1"], ";=0 ?=1\n>")
    }

    func testErrorShowsLineNumber() throws {
        try expect(["10 ?=1", "20 ?=)", "#=1"], "#=1\n1\nERR 20\n>")
    }

    func testReturnWithoutGosubIsAnError() throws {
        try expect(["]"], "]\nERR\n>")
    }

    // MARK: システム

    func testNewClearsProgram() throws {
        try expect(["10 ?=1", "&=0", "0"], "0\n>")
    }

    func testSpecialRegisters() throws {
        // 先頭は $0600。1 行(行番号 2、長さ 1、" ?=1" の 4 文字、CR 1 = 8 バイト)入れると末尾は $0608
        try expect(["10 ?=1", "??== ??=& ??=*"], "??== ??=& ??=*\n060006087FFF\n>")
    }

    func testLockedProgramRejectsEdits() throws {
        try expect(["10 ?=1", "&:0)=$F0", "20 ?=2"], "20 ?=2\nERR\n>")
    }

    func testChangeProgramAndSearchEnd() throws {
        // 2 本目のプログラムを $1000 に作り、1 本目に戻る
        try expect([
            "10 \"ONE\"",
            "=$1000 &=0",
            "10 \"TWO\"",
            "#=1",
            "=$600",
            "#=1",
        ], "#=1\nONE\n>")
    }

    func testRandomIsWithinRange() throws {
        // 偽の IF は行末まで飛ばすので、判定は別の行に書く
        let text = try run([
            "10 '=1234 I=1,50 R='6",
            "20 ;=R<1 \"BAD\"",
            "30 ;=R>6 \"BAD\"",
            "40 @=I+1 \"OK\"",
            "#=1",
        ], model: .nmos6502, cycles: 5_000_000)
        XCTAssertTrue(text.hasSuffix("OK\n>"), text)
        XCTAssertFalse(text.contains("BAD"), text)
    }

    func testCallMachineCode() throws {
        // $0300: LDA #$41 / JSR $F003 / RTS
        let (m, out) = try boot(.nmos6502)
        try m.bus.loadRAM([0xA9, 0x41, 0x20, 0x03, 0xF0, 0x60], at: 0x0300)
        out.bytes.removeAll()
        send(m, ">=$300 ?=1\r")
        XCTAssertEqual(out.text, ">=$300 ?=1\nA1\n>")
    }

    // MARK: 入力

    func testNumericInputEvaluatesExpression() throws {
        let (m, out) = try boot(.nmos6502)
        out.bytes.removeAll()
        send(m, "A=? ?=A*2\r", cycles: 300_000)
        send(m, "3+4\r")
        XCTAssertEqual(out.text, "A=? ?=A*2\n3+4\n14\n>")
    }

    func testCharacterInputDoesNotWait() throws {
        // キーがなければ 0、あれば文字コード
        try expect(["A=$ ?=A"], "A=$ ?=A\n0\n>")
        let (m, out) = try boot(.nmos6502)
        send(m, "10 @ K=$ @=(K<>0)\r", cycles: 300_000)
        send(m, "20 ?=K\r", cycles: 300_000)
        out.bytes.removeAll()
        send(m, "#=1\r", cycles: 300_000)
        send(m, "x", cycles: 300_000)
        XCTAssertEqual(out.text, "#=1\n120\n>")
    }

    func testCtrlCBreaksRunningProgram() throws {
        let (m, out) = try boot(.cmos65C02)
        send(m, "10 #=10\r", cycles: 300_000)
        out.bytes.removeAll()
        send(m, "#=1\r", cycles: 300_000)
        send(m, "\u{03}", cycles: 300_000)
        XCTAssertEqual(out.text, "#=1\nBRK 10\n>")
    }

    /// LIST や実行の間に先打ちした行が欠けない(貼り付けを想定)。
    func testTypeAheadDuringListAndRun() throws {
        for model in [CPUModel.nmos6502, .cmos65C02] {
            let (m, out) = try boot(model)
            send(m, "10 I=1,20 ?=I .=1 @=I+1\r", cycles: 300_000)
            send(m, "20 ?=99\r", cycles: 300_000)
            out.bytes.removeAll()
            send(m, "0\r#=1\r??=$ABCD\r", cycles: 3_000_000)
            XCTAssertEqual(out.text, "0\n10 I=1,20 ?=I .=1 @=I+1\n20 ?=99\n>#=1\n"
                + (1...20).map { "\($0) " }.joined() + "99\n>??=$ABCD\nABCD\n>", "\(model)")
        }
    }

    /// Ctrl-C は先打ちのキーより後ろにあっても効き、先打ちは捨てる。
    func testCtrlCAfterTypeAhead() throws {
        let (m, out) = try boot(.nmos6502)
        send(m, "10 #=10\r", cycles: 300_000)
        out.bytes.removeAll()
        send(m, "#=1\r", cycles: 300_000)
        send(m, "abc\u{03}", cycles: 300_000)
        send(m, "?=5\r", cycles: 300_000)
        XCTAssertEqual(out.text, "#=1\nBRK 10\n>?=5\n5\n>")
    }

    func testBackspaceEditsLine() throws {
        try expect(["?=12\u{08}3"], "?=12\u{08} \u{08}3\n13\n>")
    }

    func testWarmStartKeepsProgram() throws {
        let (m, out) = try boot(.nmos6502)
        send(m, "10 ?=7\r", cycles: 300_000)
        send(m, ">=$F009\r", cycles: 300_000)    // モニタへ戻る
        XCTAssertTrue(out.text.hasSuffix("*"), out.text)
        send(m, "g 8003\r", cycles: 300_000)
        out.bytes.removeAll()
        send(m, "#=1\r")
        XCTAssertEqual(out.text, "#=1\n7\n>")
    }

    // MARK: GAME65G.md / GAME65G.ja.md の例

    func testDocMultiplicationTable() throws {
        let text = try run([
            "10 I=1,9",
            "20 J=1,9 ?(3)=I*J @=J+1",
            "30 / @=I+1",
            "#=1",
        ], model: .nmos6502, cycles: 5_000_000)
        let rows = (1...9).map { i in (1...9).map { j in String(repeating: " ", count: 3 - String(i * j).count) + String(i * j) }.joined() }
        XCTAssertEqual(text, "#=1\n" + rows.joined(separator: "\n") + "\n>")
        XCTAssertTrue(text.contains("  1  2  3  4  5  6  7  8  9\n"))
        XCTAssertTrue(text.contains("  9 18 27 36 45 54 63 72 81\n>"))
    }

    func testDocGuessingGame() throws {
        let (m, out) = try boot(.nmos6502)
        for line in [
            "10 \"PRESS A KEY\" / @ N='100 K=$ @=(K<>0)",
            "20 C=0",
            "30 \"1-100? \" G=? C=C+1",
            "40 ;=G<N \"UP\" / #=30",
            "50 ;=G>N \"DOWN\" / #=30",
            "60 \"OK \" ?=C / #=-1",
        ] {
            send(m, line + "\r", cycles: 300_000)
        }
        send(m, "#=1\r", cycles: 50_000)
        XCTAssertTrue(out.text.hasSuffix("PRESS A KEY\n"), out.text)
        send(m, " ", cycles: 300_000)
        // 2分探索で当てる
        var low = 1, high = 100, tries = 0
        while tries < 10 {
            XCTAssertTrue(out.text.hasSuffix("1-100? "), out.text)
            let guess = (low + high) / 2
            tries += 1
            out.bytes.removeAll()
            send(m, "\(guess)\r", cycles: 300_000)
            if out.text.contains("UP") {
                low = guess + 1
            } else if out.text.contains("DOWN") {
                high = guess - 1
            } else {
                XCTAssertEqual(out.text, "\(guess)\nOK \(tries)\n>")
                return
            }
        }
        XCTFail("10 回で当たらなかった: \(out.text)")
    }

    func testArrayAfterProgramEnd() throws {
        try expect(["10 ?=1", "A=&+1 A(0)=-7 ?=A(0) ??=A"], "A=&+1 A(0)=-7 ?=A(0) ??=A\n-70609\n>")
    }
}
