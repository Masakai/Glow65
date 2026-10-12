import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// tutorial/05-usr の内容(BASIC から機械語を呼ぶ)が、実際の動作と一致することを確かめる。
final class TutorialUSRTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    }

    private func program(_ name: String) throws -> [UInt8] {
        [UInt8](try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("tutorial/\(name).bin")), "\(name).bin がない"))
    }

    /// モニタと BASIC を載せ、RAM に機械語を置いてから、BASIC を起動した状態のマシン。
    final class BasicSession {
        let machine = Machine()
        var bytes: [UInt8] = []

        init(root: URL, loading programs: [(bytes: [UInt8], at: UInt16)]) throws {
            let monitor = try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("ROM/monitor.bin")))
            guard let basic = try? Data(contentsOf: root.appendingPathComponent("ROM/basic/build/basic.bin")) else {
                throw XCTSkip("basic.bin がない。Tools/build_basic.sh を実行する")
            }
            machine.bus.loadROM([UInt8](basic), at: 0xC000)
            machine.bus.loadROM([UInt8](monitor), at: 0xF000)
            machine.uart.onTransmit = { [unowned self] in self.bytes.append($0) }
            machine.powerOn()
            for p in programs { try machine.bus.loadRAM(p.bytes, at: p.at) }   // 電源投入で RAM が消えたあとに置く
            machine.run(cycles: 50_000)
            send("b\r", cycles: 200_000)
            send("\r", cycles: 5_000_000)     // MEMORY SIZE?
            send("\r", cycles: 500_000)       // TERMINAL WIDTH?
        }

        @discardableResult
        func send(_ text: String, cycles: Int = 2_000_000) -> String {
            bytes.removeAll()
            for b in text.utf8 { machine.uart.receive(b) }
            machine.run(cycles: cycles)
            return String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\r", with: "")
        }
    }

    func testBuildsMatchSources() throws {
        XCTAssertEqual(try program("usr_double").count, 21)
        XCTAssertEqual(try program("usr_hello").count, 37)
    }

    func testListing() throws {
        let c = try TutorialChapterTests.Console(root: root)
        try c.machine.bus.loadRAM(try program("usr_double"), at: 0x0300)
        XCTAssertEqual(c.type("l 0300 0312\r").filter { $0.hasPrefix("03") }, [
            "0300  20 0F 03  JSR   $030F",
            "0303  06 B5     ASL   $B5",
            "0305  26 B4     ROL   $B4",
            "0307  A5 B4     LDA   $B4",
            "0309  A4 B5     LDY   $B5",
            "030B  20 12 03  JSR   $0312",
            "030E  60        RTS",
            "030F  6C 06 00  JMP   ($0006)",
            "0312  6C 08 00  JMP   ($0008)",
        ])
    }

    /// 手順書: BASIC の中の USR の入り口(10-12 番地)と、ヘルパーのベクタ(6-9 番地)
    func testTheVectorsInPageZero() throws {
        let s = try BasicSession(root: root, loading: [])
        let out = s.send("PRINT PEEK(10);PEEK(11);PEEK(12)\r")
        XCTAssertTrue(out.contains(" 76  219  207"), out)            // JMP $CFDB(FCERR)
        // 6-9 番地は、AYINT($CF52)と GIVAYF($D125)のアドレス
        let v = s.send("PRINT PEEK(6);PEEK(7);PEEK(8);PEEK(9)\r")
        XCTAssertTrue(v.contains(" 82  207  37  209"), v)
    }

    func testUSRBeforeSettingTheVectorIsAnError() throws {
        let s = try BasicSession(root: root, loading: [])
        XCTAssertTrue(s.send("PRINT USR(21)\r").contains("?ILLEGAL QUANTITY ERROR"))
    }

    func testDoubling() throws {
        let s = try BasicSession(root: root, loading: [(try program("usr_double"), 0x0300)])
        s.send("POKE 11,0:POKE 12,3\r")
        XCTAssertTrue(s.send("PRINT USR(21)\r").contains(" 42"))
        XCTAssertTrue(s.send("PRINT USR(1000)\r").contains(" 2000"))
        XCTAssertTrue(s.send("PRINT USR(-5)\r").contains("-10"))
        XCTAssertTrue(s.send("PRINT USR(16383)\r").contains(" 32766"))
        // 16384 × 2 = 32768 は 16 ビットの符号付き整数に入らず、負の数になる
        XCTAssertTrue(s.send("PRINT USR(16384)\r").contains("-32768"))
        XCTAssertTrue(s.send("PRINT USR(20000)\r").contains("-25536"))
        // 練習: 32767 × 2 = 65534 は 16 ビットで -2。40000 は、そもそも整数に直せない
        XCTAssertTrue(s.send("PRINT USR(32767)\r").contains("-2"))
        XCTAssertTrue(s.send("PRINT USR(40000)\r").contains("?ILLEGAL QUANTITY ERROR"))
    }

    func testDoublingInsideAProgram() throws {
        let s = try BasicSession(root: root, loading: [(try program("usr_double"), 0x0300)])
        s.send("POKE 11,0:POKE 12,3\r")
        let out = s.send("FOR I=1 TO 5:PRINT USR(I);:NEXT\r", cycles: 4_000_000)
        XCTAssertTrue(out.contains(" 2  4  6  8  10"), out)
    }

    func testHalvingExercise() throws {
        let s = try BasicSession(root: root, loading: [(try program("usr_double"), 0x0300)])
        s.send("POKE 11,0:POKE 12,3\r")
        // モニタではなく BASIC の POKE で、同じ 4 バイトを書き換える(LSR $B4 / ROR $B5 = 46 B4 66 B5)
        s.send("POKE 771,70:POKE 772,180:POKE 773,102:POKE 774,181\r")
        XCTAssertTrue(s.send("PRINT USR(42)\r").contains(" 21"))
        XCTAssertTrue(s.send("PRINT USR(7)\r").contains(" 3"))
    }

    func testHelloFromBasic() throws {
        let s = try BasicSession(root: root, loading: [(try program("usr_hello"), 0x0300)])
        s.send("POKE 11,0:POKE 12,3\r")
        let out = s.send("A=USR(0)\r")
        XCTAssertTrue(out.contains("HELLO FROM ASSEMBLY"), out)
        let loop = s.send("10 FOR I=1 TO 3:A=USR(0):NEXT\rRUN\r", cycles: 4_000_000)
        XCTAssertEqual(loop.components(separatedBy: "HELLO FROM ASSEMBLY").count - 1, 3, loop)
    }
}
