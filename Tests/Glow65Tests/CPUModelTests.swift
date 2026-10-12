import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// CPU の種類(6502 / 65C02)の切り替えと、ボード全体での 65C02 の動作。
final class CPUModelTests: XCTestCase {
    private func monitorImage() throws -> [UInt8] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../ROM/monitor.bin")
            .standardized
        return [UInt8](try XCTUnwrap(try? Data(contentsOf: url)))
    }

    func testDefaultIsNMOS() {
        XCTAssertEqual(Machine().cpuModel, .nmos6502)
        XCTAssertEqual(MachineRunner().machine.cpuModel, .nmos6502)
    }

    func testModelChangesOnlyWhilePoweredOff() {
        let machine = Machine()
        XCTAssertTrue(machine.setCPUModel(.cmos65C02))
        XCTAssertEqual(machine.cpuModel, .cmos65C02)
        machine.powerOn()
        XCTAssertFalse(machine.setCPUModel(.nmos6502))
        XCTAssertEqual(machine.cpuModel, .cmos65C02)
        machine.powerOff()
        XCTAssertEqual(machine.cpuModel, .cmos65C02, "電源を切っても CPU の種類は変わらない")
        XCTAssertTrue(machine.setCPUModel(.nmos6502))
    }

    func testRunnerIgnoresModelChangeWhilePoweredOn() {
        let runner = MachineRunner()
        runner.setCPUModel(.cmos65C02)
        runner.drainForTesting()
        XCTAssertEqual(runner.snapshot.cpuModel, .cmos65C02)
        runner.powerOn()
        runner.setCPUModel(.nmos6502)
        runner.drainForTesting()
        XCTAssertEqual(runner.snapshot.cpuModel, .cmos65C02)
        runner.powerOff()
        runner.setCPUModel(.nmos6502)
        runner.drainForTesting()
        XCTAssertEqual(runner.snapshot.cpuModel, .nmos6502)
    }

    /// 同じプログラムが、65C02 では INC A として動き、6502 では未定義命令(NOP)になる。
    func testMonitorRunsA65C02Program() throws {
        let image = try monitorImage()
        for (model, expected) in [(CPUModel.cmos65C02, UInt8(6)), (CPUModel.nmos6502, UInt8(5))] {
            let machine = Machine(cpuModel: model)
            machine.bus.loadROM(image, at: 0xF000)
            machine.powerOn()
            machine.run(cycles: 20_000)
            // LDA #5; INC A; STA $0310; RTS
            try machine.bus.loadRAM([0xA9, 0x05, 0x1A, 0x8D, 0x10, 0x03, 0x60], at: 0x0300)
            for b in "g 0300\r".utf8 { machine.uart.receive(b) }
            machine.run(cycles: 100_000)
            XCTAssertEqual(machine.bus.ram[0x0310], expected, "\(model)")
        }
    }

    func testWaitAndStopLightTheHaltIndicator() throws {
        let runner = MachineRunner(cpuModel: .cmos65C02)
        var rom = [UInt8](repeating: 0xFF, count: MemoryMap.romSize)
        // $F000: WAI、続いて STP
        rom[0x3000] = 0xCB
        rom[0x3001] = 0xDB
        rom[0x3FFC] = 0x00
        rom[0x3FFD] = 0xF0
        runner.machine.bus.loadROM(rom)
        runner.powerOn()
        runner.setSpeed(.mhz1)
        runner.drainForTesting()
        XCTAssertFalse(runner.snapshot.isHalted)
        runner.advanceForTesting(seconds: 0.01)
        var s = runner.snapshot
        XCTAssertTrue(s.isRunning)
        XCTAssertTrue(s.isWaiting)
        XCTAssertTrue(s.isHalted)

        runner.triggerNMI()   // NMI ベクタは $FFFA(ROM 上は $FF のまま)。WAI から再開して STP へ
        runner.drainForTesting()
        runner.advanceForTesting(seconds: 0.001)
        s = runner.snapshot
        XCTAssertFalse(s.isWaiting)
    }

    func testStopInstructionHaltsUntilReset() throws {
        let runner = MachineRunner(cpuModel: .cmos65C02)
        var rom = [UInt8](repeating: 0xFF, count: MemoryMap.romSize)
        rom[0x3000] = 0xDB
        rom[0x3FFC] = 0x00
        rom[0x3FFD] = 0xF0
        runner.machine.bus.loadROM(rom)
        runner.powerOn()
        runner.setSpeed(.mhz1)
        runner.drainForTesting()
        runner.advanceForTesting(seconds: 0.01)
        XCTAssertTrue(runner.snapshot.isStopped)
        XCTAssertTrue(runner.snapshot.isHalted)
        runner.reset()
        runner.drainForTesting()
        XCTAssertFalse(runner.snapshot.isStopped)
    }
}
