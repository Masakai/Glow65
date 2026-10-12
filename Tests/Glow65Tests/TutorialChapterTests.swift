import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// tutorial/ の第 2 章(足し算)と第 3 章(UART)の内容が、実際の動作と一致することを確かめる。
final class TutorialChapterTests: XCTestCase {
    // MARK: 道具

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    }

    private func program(_ name: String) throws -> [UInt8] {
        let data = try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("tutorial/\(name).bin")), "\(name).bin がない")
        return [UInt8](data)
    }

    final class Console {
        let machine = Machine()
        var bytes: [UInt8] = []
        init(root: URL) throws {
            let monitor = try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("ROM/monitor.bin")))
            machine.bus.loadROM([UInt8](monitor), at: 0xF000)
            machine.uart.onTransmit = { [unowned self] in self.bytes.append($0) }
            machine.powerOn()
            machine.run(cycles: 20_000)
        }
        /// 入力して実行し、出力を行に分けて返す(行末の空白は除く)。
        @discardableResult
        func type(_ text: String, cycles: Int = 400_000) -> [String] {
            bytes.removeAll()
            for b in text.utf8 { machine.uart.receive(b) }
            machine.run(cycles: cycles)
            return String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\r", with: "")
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
        }
    }

    // MARK: ビルドの整合

    /// コミットしてある .bin が、.s から作り直したものと同じであること(cc65 があるときだけ)
    func testCommittedBinariesMatchTheSources() throws {
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        which.arguments = ["which", "ca65"]
        which.standardOutput = Pipe()
        which.standardError = Pipe()
        try which.run()
        which.waitUntilExit()
        guard which.terminationStatus == 0 else { throw XCTSkip("ca65 がない") }
        for name in ["counter", "add", "hello", "hello_monitor", "echo", "echo_upper", "usr_double", "usr_hello", "nmi_count", "irq_echo"] {
            let out = FileManager.default.temporaryDirectory.appendingPathComponent("glow65-\(name)-\(UUID().uuidString).bin")
            defer { try? FileManager.default.removeItem(at: out) }
            let p = Process()
            p.executableURL = root.appendingPathComponent("Tools/assemble.sh")
            p.arguments = [root.appendingPathComponent("tutorial/\(name).s").path, out.path]
            p.standardOutput = Pipe()
            p.standardError = Pipe()
            try p.run()
            p.waitUntilExit()
            XCTAssertEqual(p.terminationStatus, 0, "\(name).s のアセンブルに失敗")
            XCTAssertEqual([UInt8](try Data(contentsOf: out)), try program(name), "\(name).bin が \(name).s と食い違う")
        }
    }

    // MARK: 第 2 章 足し算

    func testAddListingAndSizes() throws {
        XCTAssertEqual(try program("add").count, 20)
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("add"), at: 0x0300)
        XCTAssertEqual(c.type("l 0300 0313\r").filter { $0.hasPrefix("03") }, [
            "0300  18        CLC",
            "0301  AD F0 03  LDA   $03F0",
            "0304  6D F2 03  ADC   $03F2",
            "0307  8D F4 03  STA   $03F4",
            "030A  AD F1 03  LDA   $03F1",
            "030D  6D F3 03  ADC   $03F3",
            "0310  8D F5 03  STA   $03F5",
            "0313  60        RTS",
        ])
    }

    func testAddExamplesRunAndReturnToThePrompt() throws {
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("add"), at: 0x0300)
        // 5 + 7 = 12
        var lines = c.type("e 03f0 05 00 07 00\rg 0300\rd 03f0 03f5\r")
        XCTAssertTrue(lines.contains("03F0: 05 00 07 00 0C 00 00 00 CE F3 CE F3 00 00 00 00"), "\(lines)")
        XCTAssertEqual(lines.last, "*")                     // RTS でモニタに戻った
        // $01FF + $0001 = $0200(下位バイトの繰り上がりが上位バイトに届く)
        lines = c.type("e 03f0 ff 01 01 00\rg 0300\rd 03f0 03f5\r")
        XCTAssertTrue(lines.contains("03F0: FF 01 01 00 00 02 00 00 CE F3 CE F3 00 00 00 00"), "\(lines)")
        // $FFFF + $0001 = $0000(最上位からあふれた繰り上がりは保存されない)
        lines = c.type("e 03f0 ff ff 01 00\rg 0300\rd 03f0 03f5\r")
        XCTAssertTrue(lines.contains("03F0: FF FF 01 00 00 00 00 00 CE F3 CE F3 00 00 00 00"), "\(lines)")
    }

    /// 手順書の表: $01FF + $0001 の 1 命令ごとの A と C
    func testAddCarryTable() throws {
        let machine = Machine()
        machine.powerOn()
        try machine.bus.loadRAM(try program("add"), at: 0x0300)
        try machine.bus.loadRAM([0xFF, 0x01, 0x01, 0x00], at: 0x03F0)
        machine.cpu.pc = 0x0300
        machine.cpu.a = 0x5A                            // 開始時の A は何でもよい(CLC は A を変えない)
        var rows: [(pc: UInt16, a: UInt8, carry: Bool, zero: Bool)] = []
        for _ in 0..<8 {
            let pc = machine.cpu.pc
            machine.step()
            rows.append((pc, machine.cpu.a, machine.cpu.p & CPU6502.Flag.carry != 0, machine.cpu.p & CPU6502.Flag.zero != 0))
        }
        XCTAssertEqual(rows.map { $0.pc }, [0x0300, 0x0301, 0x0304, 0x0307, 0x030A, 0x030D, 0x0310, 0x0313])
        XCTAssertEqual(rows.map { $0.a }, [0x5A, 0xFF, 0x00, 0x00, 0x01, 0x02, 0x02, 0x02])
        XCTAssertEqual(rows.map { $0.carry }, [false, false, true, true, true, false, false, false])
        XCTAssertTrue(rows[2].zero)                       // 最初の ADC の結果は 0
    }

    func testAddSteppingVariantLoopsForever() throws {
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("add"), at: 0x0300)
        c.type("e 03f0 ff 01 01 00\re 0313 4c 00 03\rg 0300\r")        // RTS を JMP $0300 に替える
        let pc = c.machine.cpu.pc
        XCTAssertTrue((0x0300...0x0315).contains(pc), "ループの中にいる: \(String(pc, radix: 16))")
        XCTAssertEqual(Array(c.machine.bus.ram[0x03F4...0x03F5]), [0x00, 0x02])
    }

    func testSubtractExercise() throws {
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("add"), at: 0x0300)
        // E 0300 38 / E 0304 ED F2 03 / E 030D ED F3 03 : $0200 - $0001 = $01FF
        let lines = c.type("e 03f0 00 02 01 00\re 0300 38\re 0304 ed f2 03\re 030d ed f3 03\rg 0300\rd 03f0 03f5\r")
        XCTAssertTrue(lines.contains("03F0: 00 02 01 00 FF 01 00 00 CE F3 CE F3 00 00 00 00"), "\(lines)")
    }

    // MARK: 第 3 章 UART

    func testHelloListingAndSizes() throws {
        XCTAssertEqual(try program("hello").count, 40)
        XCTAssertEqual(try program("hello_monitor").count, 31)
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("hello"), at: 0x0300)
        XCTAssertEqual(c.type("l 0300 0317\r").filter { $0.hasPrefix("03") }, [
            "0300  A2 00     LDX   #$00",
            "0302  BD 18 03  LDA   $0318,X",
            "0305  F0 10     BEQ   $0317",
            "0307  A8        TAY",
            "0308  AD 00 A0  LDA   $A000",
            "030B  29 02     AND   #$02",
            "030D  F0 F9     BEQ   $0308",
            "030F  98        TYA",
            "0310  8D 01 A0  STA   $A001",
            "0313  E8        INX",
            "0314  4C 02 03  JMP   $0302",
            "0317  60        RTS",
        ])
    }

    func testHelloPrintsAndReturnsToThePrompt() throws {
        for name in ["hello", "hello_monitor"] {
            let c = try Console(root: root)
            try c.machine.bus.loadRAM(try program(name), at: 0x0300)
            let lines = c.type("g 0300\r")
            XCTAssertTrue(lines.contains("HELLO, GLOW65"), "\(name): \(lines)")
            XCTAssertEqual(lines.last, "*", name)
        }
    }

    /// 手順書: 最初の文字 'H'($48)は、アドレスバス $A001、データバス $48 で書き込まれる
    func testHelloFirstWriteToTheUART() throws {
        let machine = Machine()
        machine.powerOn()
        try machine.bus.loadRAM(try program("hello"), at: 0x0300)
        machine.cpu.pc = 0x0300
        let probe = PanelProbe()
        probe.recordsAccesses = true
        machine.bus.probe = probe
        var sent: [UInt8] = []
        machine.uart.onTransmit = { sent.append($0) }
        for _ in 0..<12 where sent.isEmpty { machine.step() }
        XCTAssertEqual(sent, [0x48])
        let write = try XCTUnwrap(probe.accesses.last(where: { $0.isWrite }))
        XCTAssertEqual(write.address, 0xA001)
        XCTAssertEqual(write.data, 0x48)
        // 状態レジスタ($A000)を読む LDA が、その前にある
        XCTAssertTrue(probe.accesses.contains { $0.address == 0xA000 && !$0.isWrite })
    }

    // MARK: 第 4 章 エコー

    func testEchoListingAndSizes() throws {
        XCTAssertEqual(try program("echo").count, 40)
        XCTAssertEqual(try program("echo_upper").count, 50)
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("echo"), at: 0x0300)
        XCTAssertEqual(c.type("l 0300 0327\r").filter { $0.hasPrefix("03") }, [
            "0300  AD 00 A0  LDA   $A000",
            "0303  29 01     AND   #$01",
            "0305  F0 F9     BEQ   $0300",
            "0307  AD 01 A0  LDA   $A001",
            "030A  C9 0D     CMP   #$0D",
            "030C  F0 0F     BEQ   $031D",
            "030E  A8        TAY",
            "030F  AD 00 A0  LDA   $A000",
            "0312  29 02     AND   #$02",
            "0314  F0 F9     BEQ   $030F",
            "0316  98        TYA",
            "0317  8D 01 A0  STA   $A001",
            "031A  4C 00 03  JMP   $0300",
            "031D  A9 0D     LDA   #$0D",
            "031F  20 03 F0  JSR   $F003",
            "0322  A9 0A     LDA   #$0A",
            "0324  20 03 F0  JSR   $F003",
            "0327  60        RTS",
        ])
    }

    func testEchoSendsKeysBackAndReturnsOnEnter() throws {
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("echo"), at: 0x0300)
        c.type("g 0300\r")
        // 文字を打つと、プログラムが送り返す。Enter で改行を送って戻り、プロンプトが出る。
        let lines = c.type("hello\r")
        XCTAssertEqual(lines, ["hello", "*"])
    }

    func testEchoTypeTypedByTheTutorialBytes() throws {
        // 手順書の `E 0300 ...` の 1 行をそのまま入力しても、同じプログラムになる
        let c = try Console(root: root)
        _ = c.type("e 0300 ad 00 a0 29 01 f0 f9 ad 01 a0 c9 0d f0 0f a8 ad 00 a0 29 02 f0 f9 98 8d 01 a0 4c 00 03 a9 0d 20 03 f0 a9 0a 20 03 f0 60\r", cycles: 600_000)
        XCTAssertEqual(Array(c.machine.bus.ram[0x300..<0x328]), try program("echo"))
    }

    func testEchoExerciseFinishWithAPeriod() throws {
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("echo"), at: 0x0300)
        c.type("e 030b 2e\rg 0300\r")
        // Enter は終わりの印ではなくなり、ほかのキーと同じようにエコーされる(CR は行頭に戻すだけ)
        let lines = c.type("a\rb.")
        XCTAssertEqual(lines, ["ab", "*"])
    }

    func testEchoUpperMakesCapitals() throws {
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("echo_upper"), at: 0x0300)
        c.type("g 0300\r")
        let lines = c.type("Hello, World 123 `[{\r")
        XCTAssertEqual(lines, ["HELLO, WORLD 123 `[{", "*"])
    }

    /// 手順書: 文字を読むときのバス(`$A001`、データバスは文字の ASCII コード)、送るときも同じ
    func testEchoBusAccessesForOneKey() throws {
        let machine = Machine()
        machine.powerOn()
        try machine.bus.loadRAM(try program("echo"), at: 0x0300)
        machine.cpu.pc = 0x0300
        let probe = PanelProbe()
        probe.recordsAccesses = true
        machine.bus.probe = probe
        var sent: [UInt8] = []
        machine.uart.onTransmit = { sent.append($0) }
        for _ in 0..<3 { machine.step() }                           // 文字が来る前: 状態を読むループ
        XCTAssertTrue(probe.accesses.contains { $0.address == 0xA000 && !$0.isWrite })
        XCTAssertFalse(probe.accesses.contains { $0.address == 0xA001 })
        machine.uart.receive(0x68)                                  // 'h'
        let receivedBefore = machine.uart.receiveCount
        for _ in 0..<30 where sent.isEmpty { machine.step() }
        XCTAssertEqual(sent, [0x68])
        XCTAssertEqual(machine.uart.receiveCount, receivedBefore + 1)   // RX の LED
        XCTAssertEqual(machine.uart.transmitCount, 1)                   // TX の LED
        let read = try XCTUnwrap(probe.accesses.first { $0.address == 0xA001 && !$0.isWrite })
        XCTAssertEqual(read.data, 0x68)
        let write = try XCTUnwrap(probe.accesses.last { $0.address == 0xA001 && $0.isWrite })
        XCTAssertEqual(write.data, 0x68)
        XCTAssertEqual(0x68, 0b0110_1000)                           // D6、D5、D3
    }

    func testHelloChangeTheMessage() throws {
        let c = try Console(root: root)
        try c.machine.bus.loadRAM(try program("hello"), at: 0x0300)
        let lines = c.type("e 0318 47 4f 4f 44 0d 0a 00\rg 0300\r")      // "GOOD" + CR LF + 0
        XCTAssertTrue(lines.contains("GOOD"), "\(lines)")
        XCTAssertFalse(lines.contains { $0.contains("HELLO") })
        XCTAssertEqual(lines.last, "*")
        // 改行(0D 0A)を付けなければ、プロンプトは文字のすぐ後ろに出る
        let c2 = try Console(root: root)
        try c2.machine.bus.loadRAM(try program("hello"), at: 0x0300)
        let lines2 = c2.type("e 0318 47 4f 4f 44 00\rg 0300\r")
        XCTAssertEqual(lines2.last, "GOOD*")
    }
}
