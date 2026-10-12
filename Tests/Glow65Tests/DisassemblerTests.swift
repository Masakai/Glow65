import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// モニタの `L`(逆アセンブル)コマンドを、CPU コアの命令表から作った基準と突き合わせる。
final class DisassemblerTests: XCTestCase {
    private func makeMachine(_ model: CPUModel = .nmos6502) throws -> (Machine, MonitorOutput) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
        let data = try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("ROM/monitor.bin")))
        let machine = Machine(cpuModel: model)
        machine.bus.loadROM([UInt8](data), at: 0xF000)
        let out = MonitorOutput()
        machine.uart.onTransmit = { out.bytes.append($0) }
        machine.powerOn()
        machine.run(cycles: 20_000)
        return (machine, out)
    }

    final class MonitorOutput {
        var bytes: [UInt8] = []
        var lines: [String] {
            String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\r", with: "")
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
        }
    }

    private func command(_ machine: Machine, _ out: MonitorOutput, _ text: String, cycles: Int = 400_000) -> [String] {
        out.bytes.removeAll()
        for b in text.utf8 { machine.uart.receive(b) }
        machine.run(cycles: cycles)
        return out.lines
    }

    /// 期待する 1 行(書式の仕様): `AAAA  BB BB BB  MNEMON OPERAND`
    private func expectedLine(
        address: UInt16, opcode: UInt8, b1: UInt8, b2: UInt8, model: CPUModel = .nmos6502
    ) -> String {
        let info = (model == .cmos65C02 ? CPU6502.table65C02 : CPU6502.table)[Int(opcode)]
        let hex2 = { (v: UInt8) in String(format: "%02X", v) }
        var bytes = [opcode]
        var mnemonic = String(describing: info.op).uppercased()
        if [.rmb, .smb, .bbr, .bbs].contains(info.op) { mnemonic += String((opcode >> 4) & 7) }
        var operand = ""
        if info.op == .illegal {
            mnemonic = ".BYTE"
            operand = "$" + hex2(opcode)
        } else {
            let abs = String(format: "$%04X", Int(b2) << 8 | Int(b1))
            switch info.mode {
            case .implied: break
            case .accumulator: operand = "A"
            case .immediate: operand = "#$" + hex2(b1); bytes.append(b1)
            case .zeroPage: operand = "$" + hex2(b1); bytes.append(b1)
            case .zeroPageX: operand = "$" + hex2(b1) + ",X"; bytes.append(b1)
            case .zeroPageY: operand = "$" + hex2(b1) + ",Y"; bytes.append(b1)
            case .absolute: operand = abs; bytes += [b1, b2]
            case .absoluteX: operand = abs + ",X"; bytes += [b1, b2]
            case .absoluteY: operand = abs + ",Y"; bytes += [b1, b2]
            case .indirect: operand = "(" + abs + ")"; bytes += [b1, b2]
            case .indexedIndirect: operand = "($" + hex2(b1) + ",X)"; bytes.append(b1)
            case .indirectIndexed: operand = "($" + hex2(b1) + "),Y"; bytes.append(b1)
            case .relative:
                let target = (Int(address) + 2 + Int(Int8(bitPattern: b1))) & 0xFFFF
                operand = String(format: "$%04X", target)
                bytes.append(b1)
            case .zeroPageIndirect: operand = "($" + hex2(b1) + ")"; bytes.append(b1)
            case .absoluteIndexedIndirect: operand = "(" + abs + ",X)"; bytes += [b1, b2]
            case .zeroPageRelative:
                let target = (Int(address) + 3 + Int(Int8(bitPattern: b2))) & 0xFFFF
                operand = "$" + hex2(b1) + "," + String(format: "$%04X", target)
                bytes += [b1, b2]
            }
        }
        let byteColumns = (0..<3).map { $0 < bytes.count ? hex2(bytes[$0]) + " " : "   " }.joined()
        let line = String(format: "%04X", address) + "  " + byteColumns + " " + mnemonic.padding(toLength: 6, withPad: " ", startingAt: 0) + operand
        return line.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
    }

    /// 全 256 オペコード × 3 通りのオペランドで、モニタの `L` が Swift 側の基準と一致する。
    private func checkEveryOpcode(_ model: CPUModel) throws {
        let (machine, out) = try makeMachine(model)
        for opcode in 0...255 {
            for (b1, b2) in [(UInt8(0x12), UInt8(0x34)), (UInt8(0xF0), UInt8(0xAB)), (UInt8(0x7F), UInt8(0x00))] {
                machine.bus.poke(0x0300, [UInt8(opcode), b1, b2])
                let lines = command(machine, out, "l 0300 0300\r", cycles: 60_000)
                let expected = expectedLine(address: 0x0300, opcode: UInt8(opcode), b1: b1, b2: b2, model: model)
                XCTAssertTrue(lines.contains(expected),
                              "\(model) opcode \(String(format: "%02X", opcode)) b1=\(b1): 期待 [\(expected)]、実際 \(lines)")
            }
        }
    }

    func testEveryOpcodeMatchesTheCoreTable() throws {
        try checkEveryOpcode(.nmos6502)
    }

    func testEveryOpcodeMatchesTheCoreTableOn65C02() throws {
        try checkEveryOpcode(.cmos65C02)
    }

    /// パネルに出す Swift 製の逆アセンブラも、同じ基準の書式と一致する。
    func testSwiftDisassemblerMatchesTheSameReference() {
        checkSwiftDisassembler(.nmos6502)
    }

    func testSwiftDisassemblerMatchesTheSameReferenceOn65C02() {
        checkSwiftDisassembler(.cmos65C02)
    }

    private func checkSwiftDisassembler(_ model: CPUModel) {
        for opcode in 0...255 {
            for (b1, b2) in [(UInt8(0x12), UInt8(0x34)), (UInt8(0xF0), UInt8(0xAB)), (UInt8(0x7F), UInt8(0x00))] {
                let memory: [UInt8] = [UInt8(opcode), b1, b2]
                let result = Disassembler.disassemble(at: 0x0300, model: model) { address in
                    let i = Int(address) - 0x0300
                    return (0..<3).contains(i) ? memory[i] : 0
                }
                // モニタの表示は「バイト欄が固定幅 + 区切り + ニーモニック6文字」。Swift 側は詰めた書式なので、
                // 空白を 1 つにそろえて比べる。
                let squeeze = { (s: String) in s.split(separator: " ").joined(separator: " ") }
                XCTAssertEqual(squeeze(result.line),
                               squeeze(expectedLine(address: 0x0300, opcode: UInt8(opcode), b1: b1, b2: b2, model: model)),
                               "\(model) opcode \(String(format: "%02X", opcode))")
            }
        }
    }

    func testTutorialCounterListing() throws {
        let (machine, out) = try makeMachine()
        try machine.bus.loadRAM([0xA9, 0x00, 0x8D, 0xF0, 0x03, 0x18, 0x69, 0x01, 0x4C, 0x02, 0x03], at: 0x0300)
        let lines = command(machine, out, "l 0300 0308\r")
        let listing = lines.filter { $0.hasPrefix("03") }
        XCTAssertEqual(listing, [
            "0300  A9 00     LDA   #$00",
            "0302  8D F0 03  STA   $03F0",
            "0305  18        CLC",
            "0306  69 01     ADC   #$01",
            "0308  4C 02 03  JMP   $0302",
        ])
    }

    func testCountDownExerciseListing() throws {
        let (machine, out) = try makeMachine()
        try machine.bus.loadRAM([0xA9, 0x00, 0x8D, 0xF0, 0x03, 0x38, 0xE9, 0x01, 0x4C, 0x02, 0x03], at: 0x0300)
        let listing = command(machine, out, "l 0305 0306\r").filter { $0.hasPrefix("03") }
        XCTAssertEqual(listing, ["0305  38        SEC", "0306  E9 01     SBC   #$01"])
    }

    func testDefaultIsSixteenInstructions() throws {
        let (machine, out) = try makeMachine()
        machine.bus.poke(0x0300, [UInt8](repeating: 0xEA, count: 40))   // NOP
        let lines = command(machine, out, "l 0300\r", cycles: 800_000)
        XCTAssertEqual(lines.filter { $0.contains("NOP") }.count, 16)
    }

    func testStopsAtTheEndOfTheAddressSpace() throws {
        let (machine, out) = try makeMachine()
        // $FFFE-$FFFF はベクタ。$FFFF を越えたら止まり、無限に回らない。
        let lines = command(machine, out, "l fff0 ffff\r", cycles: 800_000)
        XCTAssertTrue(lines.contains { $0.hasPrefix("FFF") })
        XCTAssertEqual(lines.last, "*")
    }

    func testHelpListsTheNewCommand() throws {
        let (machine, out) = try makeMachine()
        let lines = command(machine, out, "?\r")
        XCTAssertTrue(lines.contains { $0.hasPrefix("L AAAA") }, "\(lines)")
    }

    func test65C02ListingShowsTheNewInstructions() throws {
        let (machine, out) = try makeMachine(.cmos65C02)
        // BRA +2、STZ $10、PHX、INC A、LDA ($12)、JMP ($1234,X)、BBR0 $10,+4、RMB7 $20、SMB3 $21、WAI、STP
        try machine.bus.loadRAM([
            0x80, 0x02, 0x64, 0x10, 0xDA, 0x1A, 0xB2, 0x12, 0x7C, 0x34, 0x12,
            0x0F, 0x10, 0x04, 0x77, 0x20, 0xB7, 0x21, 0xCB, 0xDB,
        ], at: 0x0300)
        let listing = command(machine, out, "l 0300 0312\r", cycles: 400_000).filter { $0.hasPrefix("03") }
        XCTAssertEqual(listing, [
            "0300  80 02     BRA   $0304",
            "0302  64 10     STZ   $10",
            "0304  DA        PHX",
            "0305  1A        INC   A",
            "0306  B2 12     LDA   ($12)",
            "0308  7C 34 12  JMP   ($1234,X)",
            "030B  0F 10 04  BBR0  $10,$0312",
            "030E  77 20     RMB7  $20",
            "0310  B7 21     SMB3  $21",
            "0312  CB        WAI",
        ])
    }

    /// NMOS のマシンでは、同じバイト列が未定義命令として表示される(65C02 の命令は出ない)。
    func testNMOSListingStaysUnchangedForNewOpcodes() throws {
        let (machine, out) = try makeMachine(.nmos6502)
        try machine.bus.loadRAM([0x80, 0x1A, 0xCB], at: 0x0300)
        let listing = command(machine, out, "l 0300 0302\r").filter { $0.hasPrefix("03") }
        XCTAssertEqual(listing, [
            "0300  80        .BYTE $80",
            "0301  1A        .BYTE $1A",
            "0302  CB        .BYTE $CB",
        ])
    }
}
