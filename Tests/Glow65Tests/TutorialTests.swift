import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// tutorial/ の手順書に書いた内容が、実際の動作と一致することを確かめる。
final class TutorialTests: XCTestCase {
    /// tutorial/counter.s を組み立てたバイト列(手順書の `E 0300 ...` と同じ)
    private let counter: [UInt8] = [0xA9, 0x00, 0x8D, 0xF0, 0x03, 0x18, 0x69, 0x01, 0x4C, 0x02, 0x03]

    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    }

    func testCommittedBinaryMatchesTheTutorial() throws {
        let url = root().appendingPathComponent("tutorial/counter.bin")
        let data = try XCTUnwrap(try? Data(contentsOf: url))
        XCTAssertEqual([UInt8](data), counter)
    }

    func testBusAccessesOfTheFirstLoopMatchTheTutorialTable() {
        let machine = Machine()
        machine.powerOn()
        try! machine.bus.loadRAM(counter, at: 0x0300)
        machine.cpu.pc = 0x0300
        let probe = PanelProbe()
        probe.recordsAccesses = true
        machine.bus.probe = probe
        for _ in 0..<5 { machine.step() }   // LDA, STA, CLC, ADC, JMP

        func a(_ address: UInt16, _ data: UInt8, write: Bool = false, sync: Bool = false) -> BusAccess {
            BusAccess(address: address, data: data, isWrite: write, isSync: sync)
        }
        XCTAssertEqual(probe.accesses, [
            a(0x0300, 0xA9, sync: true), a(0x0301, 0x00),                                   // LDA #$00
            a(0x0302, 0x8D, sync: true), a(0x0303, 0xF0), a(0x0304, 0x03),
            a(0x03F0, 0x00, write: true),                                                    // STA $03F0
            a(0x0305, 0x18, sync: true),                                                     // CLC
            a(0x0306, 0x69, sync: true), a(0x0307, 0x01),                                    // ADC #$01
            a(0x0308, 0x4C, sync: true), a(0x0309, 0x02), a(0x030A, 0x03),                   // JMP $0302
        ])
    }

    func testCounterCountsWhenLoadedWithLoadRAM() throws {
        let machine = Machine()
        machine.powerOn()
        try machine.bus.loadRAM(counter, at: 0x0300)
        machine.cpu.pc = 0x0300
        machine.run(cycles: 2 + 11 * 5)          // 最初の LDA(2 サイクル)+ ループ 5 周(1 周 11 サイクル)
        XCTAssertEqual(machine.bus.ram[0x03F0], 4)  // 5 周で 0,1,2,3,4 を書き込んだ
        machine.run(cycles: 11 * 250)
        XCTAssertGreaterThan(machine.bus.ram[0x03F0], 0)
    }

    func testCounterRunsFromTheMonitorWithEAndG() throws {
        let monitor = try XCTUnwrap(try? Data(contentsOf: root().appendingPathComponent("ROM/monitor.bin")))
        let machine = Machine()
        machine.bus.loadROM([UInt8](monitor), at: 0xF000)
        machine.powerOn()
        machine.run(cycles: 20_000)
        for b in "e 0300 a9 00 8d f0 03 18 69 01 4c 02 03\r".utf8 { machine.uart.receive(b) }
        machine.run(cycles: 300_000)
        XCTAssertEqual(Array(machine.bus.ram[0x300..<0x30B]), counter)
        for b in "g 0300\r".utf8 { machine.uart.receive(b) }
        machine.run(cycles: 300_000)
        let first = machine.bus.ram[0x03F0]
        machine.run(cycles: 11 * 7)
        XCTAssertEqual(machine.bus.ram[0x03F0], first &+ 7)   // 1 周 11 サイクルで 1 ずつ増える
        XCTAssertTrue((0x0302...0x030A).contains(machine.cpu.pc), "プログラムのループ内にいる")
    }

    func testExerciseChangeTheStepToTwo() throws {
        let machine = Machine()
        machine.powerOn()
        var program = counter
        program[7] = 0x02                       // E 0307 02
        try machine.bus.loadRAM(program, at: 0x0300)
        machine.cpu.pc = 0x0300
        machine.run(cycles: 2 + 11 * 3)
        XCTAssertEqual(machine.bus.ram[0x03F0], 4)  // 3 周で 0, 2, 4 を書き込んだ
    }

    func testExerciseWriteToAnotherCell() throws {
        let machine = Machine()
        machine.powerOn()
        var program = counter
        program[3] = 0xF1                       // E 0303 F1
        try machine.bus.loadRAM(program, at: 0x0300)
        machine.cpu.pc = 0x0300
        machine.run(cycles: 2 + 11 * 3)
        XCTAssertEqual(machine.bus.ram[0x03F1], 2)
        XCTAssertEqual(machine.bus.ram[0x03F0], 0)
    }

    func testExerciseCountDown() throws {
        let machine = Machine()
        machine.powerOn()
        var program = counter
        program.replaceSubrange(5..<8, with: [0x38, 0xE9, 0x01])   // E 0305 38 E9 01 : sec / sbc #$01
        try machine.bus.loadRAM(program, at: 0x0300)
        machine.cpu.pc = 0x0300
        machine.run(cycles: 2 + 11 * 3)         // 0, 255, 254 を書き込んだ
        XCTAssertEqual(machine.bus.ram[0x03F0], 254)
    }

    func testLoadRAMBounds() throws {
        let bus = SBCBus()
        XCTAssertNoThrow(try bus.loadRAM([1, 2, 3], at: 0x7FFD))
        XCTAssertEqual(Array(bus.ram[0x7FFD...0x7FFF]), [1, 2, 3])
        XCTAssertThrowsError(try bus.loadRAM([1, 2, 3, 4], at: 0x7FFD))
        XCTAssertThrowsError(try bus.loadRAM([1], at: 0x8000))
    }

    func testProgramSpecParsing() throws {
        let url = root().appendingPathComponent("tutorial/counter.bin")
        let image = try ProgramImage.load(spec: "\(url.path)@0300")
        XCTAssertEqual(image.address, 0x0300)
        XCTAssertEqual(image.bytes, counter)
        XCTAssertEqual(image.name, "counter.bin")
        XCTAssertEqual(try ProgramImage.load(spec: "\(url.path)@$0400").address, 0x0400)
        XCTAssertThrowsError(try ProgramImage.load(spec: "\(url.path)"))
        XCTAssertThrowsError(try ProgramImage.load(spec: "\(url.path)@xyz"))
        XCTAssertThrowsError(try ProgramImage.load(spec: "/nonexistent/file.bin@0300"))
    }

    func testRunnerRefusesToLoadWhilePoweredOff() {
        let runner = MachineRunner()
        let done = expectation(description: "completion")
        runner.loadProgram(ProgramImage(name: "x", address: 0x0300, bytes: [1])) { result in
            if case .failure(.poweredOff) = result { done.fulfill() }
        }
        wait(for: [done], timeout: 2)
    }

    func testRunnerLoadsWhilePoweredOn() {
        let runner = MachineRunner()
        runner.powerOn()
        let done = expectation(description: "completion")
        runner.loadProgram(ProgramImage(name: "x", address: 0x0300, bytes: counter)) { result in
            if case .success = result { done.fulfill() }
        }
        wait(for: [done], timeout: 2)
        runner.drainForTesting()
        XCTAssertEqual(Array(runner.machine.bus.ram[0x300..<0x30B]), counter)
    }
}
