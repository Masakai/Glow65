import XCTest
@testable import Core6502

/// Klaus Dormann の 6502 機能テスト(GPLv3)。バイナリはリポジトリに含めず、
/// `Tests/Fixtures/klaus/6502_functional_test.bin` に置かれている場合のみ実行する。
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
}
