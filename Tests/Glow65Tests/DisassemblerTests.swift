import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// モニタの `L`(逆アセンブル)コマンドを、CPU コアの命令表から作った基準と突き合わせる。
final class DisassemblerTests: XCTestCase {
    private func makeMachine() throws -> (Machine, MonitorOutput) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
        let data = try XCTUnwrap(try? Data(contentsOf: root.appendingPathComponent("ROM/monitor.bin")))
        let machine = Machine()
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
    private func expectedLine(address: UInt16, opcode: UInt8, b1: UInt8, b2: UInt8) -> String {
        let info = CPU6502.table[Int(opcode)]
        let hex2 = { (v: UInt8) in String(format: "%02X", v) }
        var bytes = [opcode]
        var mnemonic = String(describing: info.op).uppercased()
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
            }
        }
        let byteColumns = (0..<3).map { $0 < bytes.count ? hex2(bytes[$0]) + " " : "   " }.joined()
        let line = String(format: "%04X", address) + "  " + byteColumns + " " + mnemonic.padding(toLength: 6, withPad: " ", startingAt: 0) + operand
        return line.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
    }

    func testEveryOpcodeMatchesTheCoreTable() throws {
        let (machine, out) = try makeMachine()
        for opcode in 0...255 {
            for (b1, b2) in [(UInt8(0x12), UInt8(0x34)), (UInt8(0xF0), UInt8(0xAB)), (UInt8(0x7F), UInt8(0x00))] {
                machine.bus.poke(0x0300, [UInt8(opcode), b1, b2])
                let lines = command(machine, out, "l 0300 0300\r", cycles: 60_000)
                let expected = expectedLine(address: 0x0300, opcode: UInt8(opcode), b1: b1, b2: b2)
                XCTAssertTrue(lines.contains(expected),
                              "opcode \(String(format: "%02X", opcode)) b1=\(b1): 期待 [\(expected)]、実際 \(lines)")
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
}
