import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// モニタの G で起動したプログラムを、G SPEED の速度で動かす機能。
final class GoSpeedTests: XCTestCase {
    private func monitorROM() throws -> [UInt8] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../ROM/monitor.bin")
            .standardized
        guard let data = try? Data(contentsOf: url) else {
            throw XCTSkip("monitor.bin がない。Tools/build_monitor.sh を実行する")
        }
        return [UInt8](data)
    }

    /// モニタ ROM を載せて電源を入れ、プロンプトが出るまで進めたランナー。
    private func makeRunner(program: [UInt8], goSpeed: SpeedSetting?) throws -> MachineRunner {
        let machine = Machine()
        machine.bus.loadROM(try monitorROM(), at: 0xF000)
        let runner = MachineRunner(machine: machine)
        runner.setGoSpeed(goSpeed)
        runner.powerOn()
        runner.drainForTesting()
        runner.advanceForTesting(seconds: 0.1)
        let image = ProgramImage(name: "test", address: 0x0300, bytes: program)
        runner.loadProgram(image) { _ in }
        runner.drainForTesting()
        return runner
    }

    private func type(_ runner: MachineRunner, _ line: String) {
        for b in line.utf8 { runner.sendInput(b) }
    }

    /// ROM を作り直して番地が動いたら、MachineRunner.MonitorHook を直す。
    func testHookAddressesMatchTheMonitorROM() throws {
        let rom = try monitorROM()
        let go = Int(MachineRunner.MonitorHook.goJump) - 0xF000
        XCTAssertEqual(Array(rom[go..<go + 3]), MachineRunner.MonitorHook.goJumpBytes)
        let loop = Int(MachineRunner.MonitorHook.commandLoop) - 0xF000
        XCTAssertEqual(Array(rom[loop..<loop + 2]), MachineRunner.MonitorHook.commandLoopBytes)
    }

    func testGoSwitchesSpeedAndThePromptRestoresIt() throws {
        // NOP; NOP; RTS
        let runner = try makeRunner(program: [0xEA, 0xEA, 0x60], goSpeed: .khz1)
        type(runner, "G 0300\r")
        runner.advanceForTesting(seconds: 0.1)
        XCTAssertEqual(runner.snapshot.speed, .khz1)
        // 1 kHz で 0.1 秒 = 100 サイクル。RTS で戻り、プロンプトに着く
        runner.advanceForTesting(seconds: 0.1)
        XCTAssertEqual(runner.snapshot.speed, .mhz1)
    }

    func testRomTargetKeepsTheSpeed() throws {
        let runner = try makeRunner(program: [0x60], goSpeed: .hz10)
        // $F000 はモニタのコールドスタート(ROM)。切り替えない
        type(runner, "G F000\r")
        runner.advanceForTesting(seconds: 0.1)
        XCTAssertEqual(runner.snapshot.speed, .mhz1)
    }

    func testOffKeepsTheSpeed() throws {
        let runner = try makeRunner(program: [0x4C, 0x00, 0x03], goSpeed: nil)
        type(runner, "G 0300\r")
        runner.advanceForTesting(seconds: 0.1)
        XCTAssertEqual(runner.snapshot.speed, .mhz1)
    }

    func testResetRestoresTheSpeed() throws {
        // JMP $0300(戻らない)
        let runner = try makeRunner(program: [0x4C, 0x00, 0x03], goSpeed: .hz10)
        type(runner, "G 0300\r")
        runner.advanceForTesting(seconds: 0.1)
        XCTAssertEqual(runner.snapshot.speed, .hz10)
        runner.reset()
        runner.drainForTesting()
        XCTAssertEqual(runner.snapshot.speed, .mhz1)
    }

    func testManualSpeedDuringGoIsKept() throws {
        let runner = try makeRunner(program: [0x4C, 0x00, 0x03], goSpeed: .hz10)
        type(runner, "G 0300\r")
        runner.advanceForTesting(seconds: 0.1)
        runner.setSpeed(.khz100)
        runner.reset()
        runner.drainForTesting()
        XCTAssertEqual(runner.snapshot.speed, .khz100)
    }
}
