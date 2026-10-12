import XCTest
@testable import Core6502

/// Klaus Dormann の 6502 機能テスト(GPLv3)。バイナリはリポジトリに含めず、
/// `Tests/Fixtures/klaus/6502_functional_test.bin` に置かれている場合のみ実行する。
/// 65C02 の拡張オペコードテストは `65C02_extended_opcodes_test.bin` と `.lst`(成功アドレスなどの読み取り用)。
final class KlausFunctionalTests: XCTestCase {
    func testFunctionalTest() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/klaus/6502_functional_test.bin")
            .standardized
        guard let data = try? Data(contentsOf: path), data.count == 0x10000 else {
            throw XCTSkip("Klaus のテストバイナリが見つからない: \(path.path)")
        }

        let mem = FlatMemory()
        mem.load([UInt8](data), at: 0)
        var cpu = CPU6502()
        cpu.pc = 0x0400
        cpu.sp = 0xFD

        let successAddress: UInt16 = 0x3469
        var previous: UInt16 = 0xFFFF
        var steps = 0
        while steps < 200_000_000 {
            previous = cpu.pc
            cpu.step(mem)
            steps += 1
            if cpu.pc == previous { break }  // 自分自身へのジャンプ = トラップ
        }

        XCTAssertEqual(
            cpu.pc, successAddress,
            "トラップ位置 $\(String(cpu.pc, radix: 16)) (成功は $3469)、命令数 \(steps)、"
                + "テスト番号 $\(String(mem.bytes[0x0200], radix: 16))"
        )
        print("Klaus 機能テスト: \(steps) 命令、\(cpu.cycles) サイクル")
    }

    /// 65C02 拡張オペコードテスト(BBR/BBS/RMB/SMB を含む。WAI/STP は割り込みテスト側なので対象外)。
    func test65C02ExtendedOpcodes() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/klaus")
            .standardized
        let binURL = dir.appendingPathComponent("65C02_extended_opcodes_test.bin")
        let lstURL = dir.appendingPathComponent("65C02_extended_opcodes_test.lst")
        guard let data = try? Data(contentsOf: binURL), data.count == 0x10000,
              let listing = try? String(contentsOf: lstURL, encoding: .isoLatin1) else {
            throw XCTSkip("Klaus の 65C02 テストが見つからない: \(binURL.path)(.lst も必要)")
        }
        let lines = listing.components(separatedBy: "\n")

        // 開始アドレス(code_segment)、成功アドレス(success の jmp *)、テスト番号(test_case)を .lst から読む
        func hex(_ line: String, _ pattern: String) -> UInt16? {
            guard let r = line.range(of: pattern, options: .regularExpression) else { return nil }
            let digits = line[r].prefix(4)
            return UInt16(digits, radix: 16)
        }
        let start = try XCTUnwrap(lines.lazy.compactMap { l in
            l.contains("code_segment = $") && l.contains(" =") ? hex(l, "^[0-9a-f]{4}(?= =)") : nil
        }.first, "code_segment が .lst にない")
        let testCase = try XCTUnwrap(lines.lazy.compactMap { l in
            l.contains("test_case") && l.contains("ds  1") ? hex(l, "^[0-9a-f]{4}(?= :)") : nil
        }.first, "test_case が .lst にない")
        let successIndex = try XCTUnwrap(lines.firstIndex { $0.contains("success         ;if you get here everything went well") })
        let success = try XCTUnwrap(hex(lines[successIndex + 1], "^[0-9a-f]{4}(?= :)"), "success の行が読めない")
        XCTAssertEqual(start, 0x0400)

        let mem = FlatMemory()
        mem.load([UInt8](data), at: 0)
        var cpu = CPU6502(model: .cmos65C02)
        cpu.pc = start
        cpu.sp = 0xFD

        var previous: UInt16 = 0xFFFF
        var steps = 0
        while steps < 200_000_000 {
            previous = cpu.pc
            cpu.step(mem)
            steps += 1
            if cpu.pc == previous { break }  // 自分自身へのジャンプ = トラップ
        }

        XCTAssertEqual(
            cpu.pc, success,
            "トラップ位置 $\(String(cpu.pc, radix: 16)) (成功は $\(String(success, radix: 16)))、命令数 \(steps)、"
                + "テスト番号 $\(String(mem.bytes[Int(testCase)], radix: 16))"
        )
        print("Klaus 65C02 拡張オペコードテスト: \(steps) 命令、\(cpu.cycles) サイクル")
    }
}
