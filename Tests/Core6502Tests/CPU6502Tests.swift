import XCTest
@testable import Core6502

final class CPU6502Tests: XCTestCase {
    /// 指定のプログラムを $0200 に置き、リセットベクタをそこへ向けた状態を作る。
    private func makeMachine(_ program: [UInt8], at origin: UInt16 = 0x0200) -> (CPU6502, FlatMemory) {
        let mem = FlatMemory()
        mem.load(program, at: origin)
        mem.bytes[0xFFFC] = UInt8(origin & 0xFF)
        mem.bytes[0xFFFD] = UInt8(origin >> 8)
        var cpu = CPU6502()
        cpu.reset(mem)
        return (cpu, mem)
    }

    private func run(_ cpu: inout CPU6502, _ mem: FlatMemory, steps: Int) {
        for _ in 0..<steps { cpu.step(mem) }
    }

    func testResetLoadsVector() {
        let (cpu, _) = makeMachine([0xEA])
        XCTAssertEqual(cpu.pc, 0x0200)
        XCTAssertEqual(cpu.sp, 0xFD)
        XCTAssertEqual(cpu.p, 0x24)
    }

    func testLoadAndFlags() {
        var (cpu, mem) = makeMachine([0xA9, 0x00, 0xA2, 0x80])  // LDA #0; LDX #$80
        run(&cpu, mem, steps: 1)
        XCTAssertEqual(cpu.a, 0)
        XCTAssertTrue(cpu.p & CPU6502.Flag.zero != 0)
        run(&cpu, mem, steps: 1)
        XCTAssertEqual(cpu.x, 0x80)
        XCTAssertTrue(cpu.p & CPU6502.Flag.negative != 0)
        XCTAssertTrue(cpu.p & CPU6502.Flag.zero == 0)
    }

    func testCycleCounts() {
        var (cpu, mem) = makeMachine([
            0xA9, 0x01,        // LDA #1        2
            0x8D, 0x00, 0x30,  // STA $3000     4
            0xBD, 0xFF, 0x20,  // LDA $20FF,X   4 (X=0)
            0xA2, 0x01,        // LDX #1        2
            0xBD, 0xFF, 0x20,  // LDA $20FF,X   5 (ページ跨ぎ)
            0x9D, 0xFF, 0x20,  // STA $20FF,X   5 (書き込みは常に5)
        ])
        XCTAssertEqual(cpu.step(mem), 2)
        XCTAssertEqual(cpu.step(mem), 4)
        XCTAssertEqual(cpu.step(mem), 4)
        XCTAssertEqual(cpu.step(mem), 2)
        XCTAssertEqual(cpu.step(mem), 5)
        XCTAssertEqual(cpu.step(mem), 5)
    }

    func testBranchCycles() {
        // BNE 不成立 2、成立 3、ページ跨ぎ 4
        var (cpu, mem) = makeMachine([0xA9, 0x00, 0xD0, 0x02, 0xF0, 0x02])
        cpu.step(mem)                       // LDA #0 → Z=1
        XCTAssertEqual(cpu.step(mem), 2)    // BNE 不成立
        XCTAssertEqual(cpu.step(mem), 3)    // BEQ 成立
        XCTAssertEqual(cpu.pc, 0x0208)

        var (cpu2, mem2) = makeMachine([0xF0, 0x7F], at: 0x02F0)  // 次命令 $02F2 → $0371
        cpu2.p |= CPU6502.Flag.zero
        XCTAssertEqual(cpu2.step(mem2), 4)
        XCTAssertEqual(cpu2.pc, 0x0371)
    }

    func testAdcBinaryOverflow() {
        var (cpu, mem) = makeMachine([0x18, 0xA9, 0x50, 0x69, 0x50])  // CLC; LDA #$50; ADC #$50
        run(&cpu, mem, steps: 3)
        XCTAssertEqual(cpu.a, 0xA0)
        XCTAssertTrue(cpu.p & CPU6502.Flag.overflow != 0)
        XCTAssertTrue(cpu.p & CPU6502.Flag.negative != 0)
        XCTAssertTrue(cpu.p & CPU6502.Flag.carry == 0)
    }

    func testSbcBinary() {
        var (cpu, mem) = makeMachine([0x38, 0xA9, 0x50, 0xE9, 0xF0])  // SEC; LDA #$50; SBC #$F0
        run(&cpu, mem, steps: 3)
        XCTAssertEqual(cpu.a, 0x60)
        XCTAssertTrue(cpu.p & CPU6502.Flag.carry == 0)
    }

    func testDecimalAdd() {
        // SED; CLC; LDA #$19; ADC #$28 → $47
        var (cpu, mem) = makeMachine([0xF8, 0x18, 0xA9, 0x19, 0x69, 0x28])
        run(&cpu, mem, steps: 4)
        XCTAssertEqual(cpu.a, 0x47)
        XCTAssertTrue(cpu.p & CPU6502.Flag.carry == 0)

        // $99 + $01 → $00、C=1
        var (cpu2, mem2) = makeMachine([0xF8, 0x18, 0xA9, 0x99, 0x69, 0x01])
        run(&cpu2, mem2, steps: 4)
        XCTAssertEqual(cpu2.a, 0x00)
        XCTAssertTrue(cpu2.p & CPU6502.Flag.carry != 0)
    }

    func testDecimalSubtract() {
        // SED; SEC; LDA #$46; SBC #$12 → $34
        var (cpu, mem) = makeMachine([0xF8, 0x38, 0xA9, 0x46, 0xE9, 0x12])
        run(&cpu, mem, steps: 4)
        XCTAssertEqual(cpu.a, 0x34)
        XCTAssertTrue(cpu.p & CPU6502.Flag.carry != 0)

        // $00 - $01 → $99、C=0
        var (cpu2, mem2) = makeMachine([0xF8, 0x38, 0xA9, 0x00, 0xE9, 0x01])
        run(&cpu2, mem2, steps: 4)
        XCTAssertEqual(cpu2.a, 0x99)
        XCTAssertTrue(cpu2.p & CPU6502.Flag.carry == 0)
    }

    func testShiftsAndRotates() {
        // LDA #$81; ASL A → $02, C=1; ROR A → $81, C=0
        var (cpu, mem) = makeMachine([0xA9, 0x81, 0x0A, 0x6A])
        run(&cpu, mem, steps: 2)
        XCTAssertEqual(cpu.a, 0x02)
        XCTAssertTrue(cpu.p & CPU6502.Flag.carry != 0)
        run(&cpu, mem, steps: 1)
        XCTAssertEqual(cpu.a, 0x81)
        XCTAssertTrue(cpu.p & CPU6502.Flag.carry == 0)
    }

    func testMemoryShift() {
        // INC $10; ASL $10 (ゼロページ)
        var (cpu, mem) = makeMachine([0xE6, 0x10, 0x06, 0x10])
        mem.bytes[0x10] = 0x40
        run(&cpu, mem, steps: 2)
        XCTAssertEqual(mem.bytes[0x10], 0x82)
        XCTAssertTrue(cpu.p & CPU6502.Flag.negative != 0)
    }

    func testJsrRts() {
        // JSR $0300; LDX #1 / $0300: LDA #5; RTS
        var (cpu, mem) = makeMachine([0x20, 0x00, 0x03, 0xA2, 0x01])
        mem.load([0xA9, 0x05, 0x60], at: 0x0300)
        XCTAssertEqual(cpu.step(mem), 6)
        XCTAssertEqual(cpu.pc, 0x0300)
        XCTAssertEqual(cpu.sp, 0xFB)
        XCTAssertEqual(mem.bytes[0x01FD], 0x02)  // 戻り番地 $0202(次命令-1)の上位
        XCTAssertEqual(mem.bytes[0x01FC], 0x02)
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 6)
        XCTAssertEqual(cpu.pc, 0x0203)
        XCTAssertEqual(cpu.a, 5)
    }

    func testIndirectJmpPageBug() {
        var (cpu, mem) = makeMachine([0x6C, 0xFF, 0x02])  // JMP ($02FF)
        mem.bytes[0x02FF] = 0x34
        mem.bytes[0x0300] = 0x99  // 正しい上位バイト(NMOS では使われない)
        mem.bytes[0x0200] = 0x6C  // 同一ページ先頭 $0200 の値が上位として使われる
        cpu.step(mem)
        XCTAssertEqual(cpu.pc, 0x6C34)
    }

    func testIndexedIndirect() {
        // LDX #4; LDA ($20,X) → ポインタは $24/$25
        var (cpu, mem) = makeMachine([0xA2, 0x04, 0xA1, 0x20])
        mem.bytes[0x24] = 0x00
        mem.bytes[0x25] = 0x30
        mem.bytes[0x3000] = 0x77
        run(&cpu, mem, steps: 2)
        XCTAssertEqual(cpu.a, 0x77)
    }

    func testIndirectIndexedPageCross() {
        // LDY #1; LDA ($20),Y → $30FF + 1 = $3100 (6サイクル)
        var (cpu, mem) = makeMachine([0xA0, 0x01, 0xB1, 0x20])
        mem.bytes[0x20] = 0xFF
        mem.bytes[0x21] = 0x30
        mem.bytes[0x3100] = 0x42
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 6)
        XCTAssertEqual(cpu.a, 0x42)
    }

    func testBrkAndRti() {
        var (cpu, mem) = makeMachine([0x00, 0xEA, 0xA9, 0x07])  // BRK; (パディング); LDA #7
        mem.bytes[0xFFFE] = 0x00
        mem.bytes[0xFFFF] = 0x04
        mem.load([0x40], at: 0x0400)  // RTI
        XCTAssertEqual(cpu.step(mem), 7)
        XCTAssertEqual(cpu.pc, 0x0400)
        XCTAssertTrue(cpu.p & CPU6502.Flag.interruptDisable != 0)
        XCTAssertEqual(mem.bytes[0x01FB] & CPU6502.Flag.break, CPU6502.Flag.break)  // 積まれた P の B=1
        XCTAssertEqual(cpu.step(mem), 6)
        XCTAssertEqual(cpu.pc, 0x0202)  // BRK は2バイト分進む
        cpu.step(mem)
        XCTAssertEqual(cpu.a, 7)
    }

    func testIrqRespectsInterruptDisable() {
        var (cpu, mem) = makeMachine([0xEA, 0xEA, 0xEA])
        mem.bytes[0xFFFE] = 0x00
        mem.bytes[0xFFFF] = 0x05
        cpu.irqLine = true
        cpu.step(mem)  // I=1 なので受け付けない
        XCTAssertEqual(cpu.pc, 0x0201)
        cpu.p &= ~CPU6502.Flag.interruptDisable
        XCTAssertEqual(cpu.step(mem), 7)
        XCTAssertEqual(cpu.pc, 0x0500)
        XCTAssertEqual(mem.bytes[0x01FB] & CPU6502.Flag.break, 0)  // IRQ では B=0
    }

    func testNmi() {
        var (cpu, mem) = makeMachine([0xEA])
        mem.bytes[0xFFFA] = 0x00
        mem.bytes[0xFFFB] = 0x06
        cpu.triggerNMI()
        XCTAssertEqual(cpu.step(mem), 7)
        XCTAssertEqual(cpu.pc, 0x0600)
    }

    func testStackOperations() {
        // LDA #$AA; PHA; LDA #0; PLA; PHP; PLP
        var (cpu, mem) = makeMachine([0xA9, 0xAA, 0x48, 0xA9, 0x00, 0x68, 0x08, 0x28])
        run(&cpu, mem, steps: 4)
        XCTAssertEqual(cpu.a, 0xAA)
        XCTAssertEqual(cpu.sp, 0xFD)
        run(&cpu, mem, steps: 1)
        XCTAssertEqual(mem.bytes[0x01FD] & 0x30, 0x30)  // PHP は B と U を立てて積む
        run(&cpu, mem, steps: 1)
        XCTAssertEqual(cpu.p & CPU6502.Flag.break, 0)
        XCTAssertEqual(cpu.p & CPU6502.Flag.unused, CPU6502.Flag.unused)
    }

    func testIllegalOpcodeIsNopAndRecorded() {
        var (cpu, mem) = makeMachine([0x02, 0xEA])
        XCTAssertEqual(cpu.step(mem), 2)
        XCTAssertEqual(cpu.lastIllegalOpcode, 0x02)
        XCTAssertEqual(cpu.pc, 0x0201)
    }

    /// 小さな実プログラム: 1 から 10 までの合計をゼロページに求める。
    func testSumLoop() {
        // LDA #0; LDX #10; loop: CLC; ADC? ではなく X を加算するため STX $00 / ADC $00
        let program: [UInt8] = [
            0xA9, 0x00,        // LDA #0
            0xA2, 0x0A,        // LDX #10
            0x86, 0x00,        // loop: STX $00
            0x18,              //       CLC
            0x65, 0x00,        //       ADC $00
            0xCA,              //       DEX
            0xD0, 0xF8,        //       BNE loop
            0x85, 0x01,        //       STA $01
            0x00,              //       BRK
        ]
        var (cpu, mem) = makeMachine(program)
        for _ in 0..<200 where mem.bytes[0x01] == 0 { cpu.step(mem) }
        XCTAssertEqual(mem.bytes[0x01], 55)
    }
}
