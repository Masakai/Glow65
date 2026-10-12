import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// tutorial/07-65c02 の内容(65C02 に切り替える)が、実際の動作と一致することを確かめる。
final class TutorialChapter65C02Tests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    }

    private func program(_ name: String) throws -> [UInt8] {
        [UInt8](try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("tutorial/\(name).bin")), "\(name).bin がない"))
    }

    private let fill = "E 03D0 " + [String](repeating: "AA", count: 16).joined(separator: " ")

    private let listing65C02 = [
        "0300  A2 0F     LDX   #$0F",
        "0302  9E D0 03  STZ   $03D0,X",
        "0305  CA        DEX",
        "0306  10 FA     BPL   $0302",
        "0308  9C F0 03  STZ   $03F0",
        "030B  A9 00     LDA   #$00",
        "030D  C9 03     CMP   #$03",
        "030F  F0 08     BEQ   $0319",
        "0311  EE F0 03  INC   $03F0",
        "0314  D0 F7     BNE   $030D",
        "0316  1A        INC   A",
        "0317  80 F4     BRA   $030D",
        "0319  8D F1 03  STA   $03F1",
        "031C  60        RTS",
    ]

    private let listing65C02On6502 = [
        "0300  A2 0F     LDX   #$0F",
        "0302  9E        .BYTE $9E",
        "0303  D0 03     BNE   $0308",
        "0305  CA        DEX",
        "0306  10 FA     BPL   $0302",
        "0308  9C        .BYTE $9C",
        "0309  F0 03     BEQ   $030E",
        "030B  A9 00     LDA   #$00",
        "030D  C9 03     CMP   #$03",
        "030F  F0 08     BEQ   $0319",
        "0311  EE F0 03  INC   $03F0",
        "0314  D0 F7     BNE   $030D",
        "0316  1A        .BYTE $1A",
        "0317  80        .BYTE $80",
        "0318  F4        .BYTE $F4",
    ]

    private let listing6502 = [
        "0300  A2 0F     LDX   #$0F",
        "0302  A9 00     LDA   #$00",
        "0304  9D D0 03  STA   $03D0,X",
        "0307  CA        DEX",
        "0308  10 FA     BPL   $0304",
        "030A  8D F0 03  STA   $03F0",
        "030D  C9 03     CMP   #$03",
        "030F  F0 0B     BEQ   $031C",
        "0311  EE F0 03  INC   $03F0",
        "0314  D0 F7     BNE   $030D",
        "0316  18        CLC",
        "0317  69 01     ADC   #$01",
        "0319  4C 0D 03  JMP   $030D",
        "031C  8D F1 03  STA   $03F1",
        "031F  60        RTS",
    ]

    private let dumpCleared = [
        "03D0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        "03E0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        "03F0: 00 03 00 00 00 00 00 00 24 F4 24 F4 00 00 00 00",
    ]

    private let dumpNotCleared = [
        "03D0: AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA",
        "03E0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00",
        "03F0: 00 00 00 00 00 00 00 00 24 F4 24 F4 00 00 00 00",
    ]

    /// 領域を $AA で埋め、`name` を読み込んで `last` まで一覧し、実行して領域と結果を見る。
    private func session(model: CPUModel, name: String, listTo last: String) throws -> (listing: [String], dump: [String], console: TutorialChapterTests.Console) {
        let c = try TutorialChapterTests.Console(root: root, cpuModel: model)
        try c.machine.bus.loadRAM(try program(name), at: 0x0300)
        c.type(fill + "\r")
        let listing = c.type("L 0300 \(last)\r").filter { $0.hasPrefix("03") }
        c.type("G 0300\r", cycles: 3_000_000)
        let dump = c.type("D 03D0 03F1\r").filter { $0.hasPrefix("03") }
        return (listing, dump, c)
    }

    func testSizes() throws {
        XCTAssertEqual(try program("clear_6502").count, 32)
        XCTAssertEqual(try program("clear_65c02").count, 29)
    }

    func testListingOn65C02Machine() throws {
        let s = try session(model: .cmos65C02, name: "clear_65c02", listTo: "031C")
        XCTAssertEqual(s.listing, listing65C02)
        XCTAssertEqual(s.dump, dumpCleared)
    }

    func testListingOn6502MachineShowsUndefinedBytes() throws {
        let s = try session(model: .nmos6502, name: "clear_65c02", listTo: "0318")
        XCTAssertEqual(s.listing, listing65C02On6502)
        XCTAssertEqual(s.dump, dumpNotCleared)
    }

    func testPlain6502ProgramGivesTheSameResultOnBothMachines() throws {
        for model in [CPUModel.nmos6502, .cmos65C02] {
            let s = try session(model: model, name: "clear_6502", listTo: "031F")
            XCTAssertEqual(s.listing, listing6502, "\(model)")
            XCTAssertEqual(s.dump, dumpCleared, "\(model)")
            XCTAssertEqual(s.console.machine.bus.peek(0x03F0), 0x00)
            XCTAssertEqual(s.console.machine.bus.peek(0x03F1), 0x03)
        }
    }

    /// 65C02 版を 6502 で動かしても、プログラムは暴走せず RTS でモニタに戻る(カウンタは進まない)。
    func testThe65C02ProgramOn6502ReturnsToTheMonitor() throws {
        let s = try session(model: .nmos6502, name: "clear_65c02", listTo: "0318")
        let c = s.console
        XCTAssertEqual(c.type("\r"), ["", "*"])
        XCTAssertEqual(c.machine.bus.peek(0x03F1), 0x00)
    }

    func testTryEdits() throws {
        // 試してみよう 1: 上限を $01 にする
        let c = try TutorialChapterTests.Console(root: root, cpuModel: .cmos65C02)
        try c.machine.bus.loadRAM(try program("clear_65c02"), at: 0x0300)
        c.type("E 030E 01\r")
        c.type("G 0300\r", cycles: 3_000_000)
        XCTAssertEqual(c.type("D 03F0 03F1\r").filter { $0.hasPrefix("03") }.map { String($0.prefix(12)) }, ["03F0: 00 01 "])
        // 試してみよう 2: PHX / PLX
        for (model, expected) in [(CPUModel.cmos65C02, "03F0: 07 "), (.nmos6502, "03F0: 00 ")] {
            let c = try TutorialChapterTests.Console(root: root, cpuModel: model)
            c.type("E 0300 A2 07 DA A2 00 FA 8E F0 03 60\r")
            c.type("G 0300\r")
            XCTAssertEqual(c.type("D 03F0 03F0\r").filter { $0.hasPrefix("03") }.map { String($0.prefix(9)) }, [expected], "\(model)")
        }
    }

    /// 章に載せた出力が、実行結果と一字一句同じであること。
    func testChapterTextShowsTheOutputs() throws {
        let shown = listing65C02 + listing65C02On6502 + listing6502 + dumpCleared + dumpNotCleared + [fill]
        for chapter in ["tutorial/07-65c02.md", "tutorial/07-65c02.ja.md"] {
            let text = try String(contentsOf: root.appendingPathComponent(chapter), encoding: .utf8)
            for line in shown {
                XCTAssertTrue(text.contains(line), "\(chapter): \(line)")
            }
            XCTAssertTrue(text.contains("32 bytes"), chapter)
            XCTAssertTrue(text.contains("29 bytes"), chapter)
        }
    }
}
