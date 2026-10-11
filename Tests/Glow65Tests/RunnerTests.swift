import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

final class RunnerTests: XCTestCase {
    /// $0200 から LDA #$55 / STA $0300 / JMP $0200 を繰り返す小さなプログラムを持つランナー。
    private func makeRunner() -> MachineRunner {
        let machine = Machine()
        var rom = [UInt8](repeating: 0xFF, count: MemoryMap.romSize)
        // ROM($F000)に置く: LDA #$55; STA $0300; JMP $F000
        let code: [UInt8] = [0xA9, 0x55, 0x8D, 0x00, 0x03, 0x4C, 0x00, 0xF0]
        for (i, b) in code.enumerated() { rom[0x3000 + i] = b }
        rom[0x3FFC] = 0x00
        rom[0x3FFD] = 0xF0
        machine.bus.loadROM(rom)
        return MachineRunner(machine: machine)
    }

    func testPowerOffShowsNothing() {
        let runner = makeRunner()
        runner.powerOn()
        runner.powerOff()
        runner.drainForTesting()
        let s = runner.snapshot
        XCTAssertFalse(s.isPoweredOn)
        XCTAssertTrue(s.address.allSatisfy { $0 == 0 })
    }

    func testFastRunProducesGlowLevels() {
        let runner = makeRunner()
        runner.powerOn()
        runner.setSpeed(.mhz1)
        runner.drainForTesting()
        runner.advanceForTesting(seconds: 0.01)
        let s = runner.snapshot
        XCTAssertTrue(s.isPoweredOn)
        // プログラムは $F000-$F007 と $0300 だけを触る。A15-A12 は常に1に近い読み出しが多い
        XCTAssertGreaterThan(s.address[15], 0.5)  // ほとんどの時間 ROM を読む
        XCTAssertEqual(s.address[14], s.address[15], accuracy: 0.2)
        XCTAssertGreaterThan(s.syncLevel, 0.2)    // 命令フェッチの割合
        XCTAssertLessThan(s.syncLevel, 0.6)
        XCTAssertGreaterThan(s.writeLevel, 0.05)  // STA による書き込みもある
        XCTAssertEqual(runner.machine.bus.ram[0x300], 0x55)
    }

    func testSlowReplayShowsOneAccessAtATime() {
        let runner = makeRunner()
        runner.powerOn()
        runner.setSpeed(.hz1)
        runner.drainForTesting()
        // 1 Hz: 最初の命令 LDA #$55(2サイクル)の1サイクル目 = オペコード取得
        for _ in 0..<5 { runner.advanceForTesting(seconds: 0.1) }  // 1回の進行は最大0.1秒
        var s = runner.snapshot
        XCTAssertEqual(s.syncLevel, 1)
        XCTAssertEqual(s.address[0], 0)  // $F000 の A0 = 0
        XCTAssertEqual(s.address[12], 1) // $F000 の A12 = 1
        XCTAssertEqual(s.data[0], 1)     // オペコード $A9 の D0 = 1
        // 命令が終わるまで、レジスタ表示は実行前の値
        XCTAssertEqual(s.a, 0)
        // 2秒後(2サイクル消化)に命令が完了し A=$55
        for _ in 0..<20 { runner.advanceForTesting(seconds: 0.1) }
        s = runner.snapshot
        XCTAssertEqual(s.a, 0x55)
    }

    func testStepAndCycleStepWhenStopped() {
        let runner = makeRunner()
        runner.powerOn()
        runner.setRunning(false)
        runner.drainForTesting()
        let pcBefore = runner.snapshot.pc
        runner.step()
        runner.drainForTesting()
        XCTAssertEqual(runner.snapshot.pc, pcBefore + 2)  // LDA #imm
        XCTAssertEqual(runner.snapshot.a, 0x55)

        // STA $0300 を1サイクルずつ: フェッチ → オペランド下位 → 上位 → 書き込み
        runner.stepCycle()
        runner.drainForTesting()
        var s = runner.snapshot
        XCTAssertEqual(s.syncLevel, 1)
        XCTAssertEqual(s.pc, pcBefore + 2)  // 命令途中は実行前のレジスタを表示
        runner.stepCycle()
        runner.stepCycle()
        runner.drainForTesting()
        runner.stepCycle()  // 4つ目のアクセス = 書き込み
        runner.drainForTesting()
        s = runner.snapshot
        XCTAssertEqual(s.writeLevel, 1)
        XCTAssertEqual(s.address[8], 1)  // $0300 の A8 = 1
        XCTAssertEqual(s.address[9], 1)  // $0300 の A9 = 1
        XCTAssertEqual(s.data[0], 1)     // データ $55 の D0 = 1
        XCTAssertEqual(runner.machine.bus.ram[0x300], 0x55)
    }

    func testSnapshotShowsTheInstructionAtPC() {
        let runner = makeRunner()
        runner.powerOn()
        runner.setSpeed(.hz1)
        runner.drainForTesting()
        // 最初に実行する命令は ROM の LDA #$55
        XCTAssertEqual(runner.snapshot.instruction?.line, "F000  A9 55    LDA #$55")
        // 1 Hz で 2 サイクル(= LDA が終わる)進めると、次の命令に変わる
        for _ in 0..<21 { runner.advanceForTesting(seconds: 0.1) }
        XCTAssertEqual(runner.snapshot.instruction?.line, "F002  8D 00 03 STA $0300")
        runner.powerOff()
        runner.drainForTesting()
        XCTAssertNil(runner.snapshot.instruction)
    }

    func testStopFreezesAndRunResumes() {
        let runner = makeRunner()
        runner.powerOn()
        runner.drainForTesting()
        runner.advanceForTesting(seconds: 0.01)
        runner.setRunning(false)
        runner.drainForTesting()
        let cycles = runner.snapshot.cycles
        runner.advanceForTesting(seconds: 0.5)
        XCTAssertEqual(runner.snapshot.cycles, cycles)
        runner.setRunning(true)
        runner.drainForTesting()
        runner.advanceForTesting(seconds: 0.01)
        XCTAssertGreaterThan(runner.snapshot.cycles, cycles)
    }
}
