import XCTest
@testable import Core6502

/// 65C02 モード(WDC W65C02S 相当)の命令・サイクル・挙動の単体テスト。
final class CPU65C02Tests: XCTestCase {
    private typealias F = CPU6502.Flag

    /// バスアクセスの回数を数えるメモリ(待機中にアクセスがないことの確認用)。
    private final class CountingMemory: Bus {
        let mem = FlatMemory()
        var accesses = 0
        func read(_ address: UInt16) -> UInt8 { accesses += 1; return mem.read(address) }
        func write(_ address: UInt16, _ value: UInt8) { accesses += 1; mem.write(address, value) }
    }

    private func make(
        _ program: [UInt8], model: CPUModel = .cmos65C02, at origin: UInt16 = 0x0200
    ) -> (CPU6502, FlatMemory) {
        let mem = FlatMemory()
        mem.load(program, at: origin)
        mem.bytes[0xFFFC] = UInt8(origin & 0xFF)
        mem.bytes[0xFFFD] = UInt8(origin >> 8)
        mem.bytes[0xFFFA] = 0x00
        mem.bytes[0xFFFB] = 0x06
        mem.bytes[0xFFFE] = 0x00
        mem.bytes[0xFFFF] = 0x05
        var cpu = CPU6502(model: model)
        cpu.reset(mem)
        return (cpu, mem)
    }

    // MARK: 分岐・スタック

    func testBRA() {
        var (cpu, mem) = make([0x80, 0x02, 0xEA, 0xEA, 0xEA])
        XCTAssertEqual(cpu.step(mem), 3)
        XCTAssertEqual(cpu.pc, 0x0204)
        // ページ跨ぎは +1(後方へ $0200 → $01xx)
        (cpu, mem) = make([0x80, 0xFC])
        XCTAssertEqual(cpu.step(mem), 4)
        XCTAssertEqual(cpu.pc, 0x01FE)
    }

    func testPushPullXY() {
        var (cpu, mem) = make([0xA2, 0x80, 0xA0, 0x00, 0xDA, 0x5A, 0xA2, 0x01, 0xA0, 0x01, 0x7A, 0xFA])
        for _ in 0..<2 { cpu.step(mem) }
        XCTAssertEqual(cpu.step(mem), 3)  // PHX
        XCTAssertEqual(cpu.step(mem), 3)  // PHY
        XCTAssertEqual(mem.bytes[0x01FD], 0x80)
        XCTAssertEqual(mem.bytes[0x01FC], 0x00)
        cpu.step(mem); cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 4)  // PLY
        XCTAssertEqual(cpu.y, 0x00)
        XCTAssertTrue(cpu.p & F.zero != 0)
        XCTAssertEqual(cpu.step(mem), 4)  // PLX
        XCTAssertEqual(cpu.x, 0x80)
        XCTAssertTrue(cpu.p & F.negative != 0)
        XCTAssertEqual(cpu.sp, 0xFD)
    }

    // MARK: メモリ操作

    func testSTZ() {
        var (cpu, mem) = make([
            0xA2, 0x03,
            0x64, 0x10,         // STZ $10        3
            0x74, 0x10,         // STZ $10,X      4
            0x9C, 0x00, 0x30,   // STZ $3000      4
            0x9E, 0x00, 0x30,   // STZ $3000,X    5
        ])
        for addr in [0x10, 0x13, 0x3000, 0x3003] { mem.bytes[addr] = 0xFF }
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 3)
        XCTAssertEqual(cpu.step(mem), 4)
        XCTAssertEqual(cpu.step(mem), 4)
        XCTAssertEqual(cpu.step(mem), 5)
        for addr in [0x10, 0x13, 0x3000, 0x3003] { XCTAssertEqual(mem.bytes[addr], 0, "$\(String(addr, radix: 16))") }
    }

    func testTRBandTSB() {
        var (cpu, mem) = make([
            0xA9, 0x0F,
            0x04, 0x10,         // TSB $10    5
            0x0C, 0x00, 0x30,   // TSB $3000  6
            0x14, 0x11,         // TRB $11    5
            0x1C, 0x01, 0x30,   // TRB $3001  6
        ])
        mem.bytes[0x10] = 0xF0       // A&M = 0 → Z=1、結果 $FF
        mem.bytes[0x3000] = 0x01     // A&M != 0 → Z=0、結果 $0F
        mem.bytes[0x11] = 0xFF       // 結果 $F0
        mem.bytes[0x3001] = 0xF0     // A&M = 0 → Z=1、変わらない
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 5)
        XCTAssertEqual(mem.bytes[0x10], 0xFF)
        XCTAssertTrue(cpu.p & F.zero != 0)
        XCTAssertEqual(cpu.step(mem), 6)
        XCTAssertEqual(mem.bytes[0x3000], 0x0F)
        XCTAssertTrue(cpu.p & F.zero == 0)
        XCTAssertEqual(cpu.step(mem), 5)
        XCTAssertEqual(mem.bytes[0x11], 0xF0)
        XCTAssertTrue(cpu.p & F.zero == 0)
        XCTAssertEqual(cpu.step(mem), 6)
        XCTAssertEqual(mem.bytes[0x3001], 0xF0)
        XCTAssertTrue(cpu.p & F.zero != 0)
    }

    func testIncDecAccumulator() {
        var (cpu, mem) = make([0xA9, 0xFF, 0x1A, 0x3A, 0x3A])
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 2)
        XCTAssertEqual(cpu.a, 0)
        XCTAssertTrue(cpu.p & F.zero != 0)
        XCTAssertEqual(cpu.step(mem), 2)
        XCTAssertEqual(cpu.a, 0xFF)
        XCTAssertTrue(cpu.p & F.negative != 0)
        cpu.step(mem)
        XCTAssertEqual(cpu.a, 0xFE)
    }

    // MARK: アドレッシング

    func testZeroPageIndirect() {
        // (zp) の 8 命令。ポインタ $10/$11 → $3000。5 サイクル
        let cases: [(opcode: UInt8, check: (CPU6502, FlatMemory) -> Bool)] = [
            (0x12, { cpu, _ in cpu.a == 0x0F | 0x30 }),                 // ORA
            (0x32, { cpu, _ in cpu.a == 0x0F & 0x30 }),                 // AND
            (0x52, { cpu, _ in cpu.a == 0x0F ^ 0x30 }),                 // EOR
            (0x72, { cpu, _ in cpu.a == 0x0F + 0x30 }),                 // ADC(C=0)
            (0x92, { _, mem in mem.bytes[0x3000] == 0x0F }),            // STA
            (0xB2, { cpu, _ in cpu.a == 0x30 }),                        // LDA
            (0xD2, { cpu, _ in cpu.a == 0x0F && cpu.p & F.carry == 0 }),  // CMP
            (0xF2, { cpu, _ in cpu.a == 0x0F &- 0x30 }),                // SBC(C=0 なので -1 も引く)
        ]
        for c in cases {
            var (cpu, mem) = make([0xA9, 0x0F, c.opcode, 0x10])
            mem.bytes[0x10] = 0x00
            mem.bytes[0x11] = 0x30
            mem.bytes[0x3000] = 0x30
            cpu.step(mem)
            XCTAssertEqual(cpu.step(mem), 5, "opcode \(String(c.opcode, radix: 16))")
            if c.opcode == 0xF2 {
                XCTAssertEqual(cpu.a, 0x0F &- 0x30 &- 1)  // C=0 のとき借りが入る
            } else {
                XCTAssertTrue(c.check(cpu, mem), "opcode \(String(c.opcode, radix: 16))")
            }
        }
    }

    func testZeroPageIndirectWrapsInZeroPage() {
        var (cpu, mem) = make([0xB2, 0xFF])
        mem.bytes[0xFF] = 0x00
        mem.bytes[0x00] = 0x30  // ポインタの上位は $0000(ゼロページ内で折り返す)
        mem.bytes[0x3000] = 0x77
        cpu.step(mem)
        XCTAssertEqual(cpu.a, 0x77)
    }

    func testJMPIndexedIndirect() {
        var (cpu, mem) = make([0xA2, 0x02, 0x7C, 0x00, 0x30])
        mem.bytes[0x3002] = 0x34
        mem.bytes[0x3003] = 0x12
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 6)
        XCTAssertEqual(cpu.pc, 0x1234)
    }

    func testJMPIndirectHasNoPageBoundaryBugOn65C02() {
        var (cpu, mem) = make([0x6C, 0xFF, 0x12])
        mem.bytes[0x12FF] = 0x34
        mem.bytes[0x1300] = 0x56   // 65C02 は ptr+1 から上位を読む
        mem.bytes[0x1200] = 0x99   // NMOS ならここを読む
        XCTAssertEqual(cpu.step(mem), 6)
        XCTAssertEqual(cpu.pc, 0x5634)

        (cpu, mem) = make([0x6C, 0xFF, 0x12], model: .nmos6502)
        mem.bytes[0x12FF] = 0x34
        mem.bytes[0x1300] = 0x56
        mem.bytes[0x1200] = 0x99
        XCTAssertEqual(cpu.step(mem), 5)
        XCTAssertEqual(cpu.pc, 0x9934)
    }

    // MARK: BIT

    func testBitImmediateChangesOnlyZ() {
        var (cpu, mem) = make([0xA9, 0x0F, 0x89, 0xF0, 0x89, 0x01])
        cpu.step(mem)
        cpu.p |= F.negative | F.overflow
        XCTAssertEqual(cpu.step(mem), 2)
        XCTAssertTrue(cpu.p & F.zero != 0)
        XCTAssertTrue(cpu.p & F.negative != 0)   // N/V は変わらない
        XCTAssertTrue(cpu.p & F.overflow != 0)
        cpu.step(mem)
        XCTAssertTrue(cpu.p & F.zero == 0)
    }

    func testBitIndexed() {
        var (cpu, mem) = make([
            0xA9, 0x01, 0xA2, 0x01,
            0x34, 0x10,         // BIT $10,X      4
            0x3C, 0x00, 0x30,   // BIT $3000,X    4
            0xA2, 0xFF,
            0x3C, 0x01, 0x30,   // BIT $3001,X    5(ページ跨ぎ)
        ])
        mem.bytes[0x11] = 0xC1
        mem.bytes[0x3001] = 0x40
        mem.bytes[0x3100] = 0x00
        cpu.step(mem); cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 4)
        XCTAssertTrue(cpu.p & F.negative != 0 && cpu.p & F.overflow != 0 && cpu.p & F.zero == 0)
        XCTAssertEqual(cpu.step(mem), 4)
        XCTAssertTrue(cpu.p & F.negative == 0 && cpu.p & F.overflow != 0 && cpu.p & F.zero != 0)
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 5)
    }

    // MARK: シフトのサイクル

    func testShiftAbsoluteXCycles() {
        for opcode: UInt8 in [0x1E, 0x3E, 0x5E, 0x7E] {
            var (cpu, mem) = make([0xA2, 0x01, opcode, 0x00, 0x30, 0xA2, 0xFF, opcode, 0x01, 0x30])
            cpu.step(mem)
            XCTAssertEqual(cpu.step(mem), 6, "opcode \(String(opcode, radix: 16))")
            cpu.step(mem)
            XCTAssertEqual(cpu.step(mem), 7, "opcode \(String(opcode, radix: 16)) ページ跨ぎ")
        }
        // INC/DEC abs,X は 7 のまま、NMOS のシフトも 7
        var (cpu, mem) = make([0xA2, 0xFF, 0xFE, 0x01, 0x30, 0xDE, 0x01, 0x30])
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 7)
        XCTAssertEqual(cpu.step(mem), 7)
        (cpu, mem) = make([0xA2, 0x01, 0x1E, 0x00, 0x30], model: .nmos6502)
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 7)
    }

    // MARK: RMB / SMB / BBR / BBS

    func testRMBandSMB() {
        for n in 0..<8 {
            var (cpu, mem) = make([UInt8(0x07 + n * 16), 0x10, UInt8(0x87 + n * 16), 0x11])
            mem.bytes[0x10] = 0xFF
            mem.bytes[0x11] = 0x00
            XCTAssertEqual(cpu.step(mem), 5)
            XCTAssertEqual(mem.bytes[0x10], ~UInt8(1 << n), "RMB\(n)")
            XCTAssertEqual(cpu.step(mem), 5)
            XCTAssertEqual(mem.bytes[0x11], UInt8(1 << n), "SMB\(n)")
        }
    }

    func testBBRandBBS() {
        for n in 0..<8 {
            let bbr = UInt8(0x0F + n * 16), bbs = UInt8(0x8F + n * 16)
            // ビットが 0 のとき BBR は成立、BBS は不成立
            var (cpu, mem) = make([bbr, 0x10, 0x02, 0xEA, 0xEA, bbs, 0x10, 0x02])
            mem.bytes[0x10] = ~UInt8(1 << n) & 0xFF
            XCTAssertEqual(cpu.step(mem), 6, "BBR\(n) 成立")
            XCTAssertEqual(cpu.pc, 0x0205)
            XCTAssertEqual(cpu.step(mem), 5, "BBS\(n) 不成立")
            XCTAssertEqual(cpu.pc, 0x0208)
            // ビットが 1 のとき BBR は不成立、BBS は成立
            (cpu, mem) = make([bbr, 0x10, 0x02, 0xEA, 0xEA, bbs, 0x10, 0x02])
            mem.bytes[0x10] = UInt8(1 << n)
            XCTAssertEqual(cpu.step(mem), 5, "BBR\(n) 不成立")
            XCTAssertEqual(cpu.pc, 0x0203)
            cpu.pc = 0x0205
            XCTAssertEqual(cpu.step(mem), 6, "BBS\(n) 成立")
            XCTAssertEqual(cpu.pc, 0x020A)
        }
    }

    func testBBRPageCrossAndBackward() {
        // $02FA: BBR0 $10,+$10 → 次の命令 $02FD + $10 = $030D(ページ跨ぎ 7 サイクル)
        var (cpu, mem) = make([0x0F, 0x10, 0x10], at: 0x02FA)
        mem.bytes[0x10] = 0x00
        XCTAssertEqual(cpu.step(mem), 7)
        XCTAssertEqual(cpu.pc, 0x030D)
        (cpu, mem) = make([0x8F, 0x10, 0xFD], at: 0x0300)  // 後方へ(-3 で自分自身)
        mem.bytes[0x10] = 0x01
        XCTAssertEqual(cpu.step(mem), 6)  // $0303 - 3 = $0300(同一ページ)
        XCTAssertEqual(cpu.pc, 0x0300)
    }

    // MARK: 割り込み・WAI・STP

    func testWAIWaitsForInterruptWithoutBusAccess() {
        let bus = CountingMemory()
        bus.mem.load([0xCB, 0xA9, 0x42], at: 0x0200)
        bus.mem.bytes[0xFFFC] = 0x00
        bus.mem.bytes[0xFFFD] = 0x02
        bus.mem.bytes[0xFFFE] = 0x00
        bus.mem.bytes[0xFFFF] = 0x05
        var cpu = CPU6502(model: .cmos65C02)
        cpu.reset(bus)
        XCTAssertEqual(cpu.step(bus), 3)  // WAI
        XCTAssertTrue(cpu.isWaiting)
        let before = bus.accesses
        let cyclesBefore = cpu.cycles
        for _ in 0..<5 { XCTAssertEqual(cpu.step(bus), 1) }
        XCTAssertEqual(bus.accesses, before)
        XCTAssertEqual(cpu.cycles, cyclesBefore + 5)

        // I フラグが立っていても IRQ で再開する。割り込みは受け付けず、次の命令(LDA #$42)へ進む
        XCTAssertTrue(cpu.p & F.interruptDisable != 0)
        cpu.irqLine = true
        XCTAssertEqual(cpu.step(bus), 2)
        XCTAssertFalse(cpu.isWaiting)
        XCTAssertEqual(cpu.a, 0x42)
        XCTAssertEqual(cpu.pc, 0x0203)
    }

    func testWAIResumesIntoIRQHandlerWhenInterruptsEnabled() {
        var (cpu, mem) = make([0x58, 0xCB, 0xEA])  // CLI; WAI
        cpu.step(mem); cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 1)
        cpu.irqLine = true
        XCTAssertEqual(cpu.step(mem), 7)
        XCTAssertEqual(cpu.pc, 0x0500)
        // 戻り番地は WAI($0201)の次の命令($0202)
        XCTAssertEqual(mem.bytes[0x01FD], 0x02)
        XCTAssertEqual(mem.bytes[0x01FC], 0x02)
    }

    func testWAIResumesOnNMI() {
        var (cpu, mem) = make([0xCB, 0xEA])
        cpu.step(mem)
        XCTAssertEqual(cpu.step(mem), 1)
        cpu.triggerNMI()
        XCTAssertEqual(cpu.step(mem), 7)
        XCTAssertEqual(cpu.pc, 0x0600)
        XCTAssertFalse(cpu.isWaiting)
    }

    func testSTPStopsUntilReset() {
        var (cpu, mem) = make([0xDB, 0xEA])
        XCTAssertEqual(cpu.step(mem), 3)
        XCTAssertTrue(cpu.isStopped)
        cpu.triggerNMI()
        cpu.irqLine = true
        cpu.p &= ~F.interruptDisable
        for _ in 0..<4 {
            XCTAssertEqual(cpu.step(mem), 1)
            XCTAssertEqual(cpu.pc, 0x0201)
        }
        XCTAssertTrue(cpu.nmiPending)  // 受け付けない
        cpu.reset(mem)
        XCTAssertFalse(cpu.isStopped)
        XCTAssertEqual(cpu.pc, 0x0200)
        XCTAssertEqual(cpu.step(mem), 3)
    }

    func testResetLeavesWaiting() {
        var (cpu, mem) = make([0xCB])
        cpu.step(mem)
        XCTAssertTrue(cpu.isWaiting)
        cpu.reset(mem)
        XCTAssertFalse(cpu.isWaiting)
    }

    func testInterruptsClearDecimalOn65C02ButNotOnNMOS() {
        for (model, expectCleared) in [(CPUModel.cmos65C02, true), (CPUModel.nmos6502, false)] {
            // BRK
            var (cpu, mem) = make([0xF8, 0x00], model: model)
            cpu.step(mem)
            XCTAssertTrue(cpu.p & F.decimal != 0)
            cpu.step(mem)
            XCTAssertEqual(cpu.p & F.decimal == 0, expectCleared, "\(model) BRK")
            XCTAssertTrue(mem.bytes[0x01FB] & F.decimal != 0)  // 積まれたステータスは D のまま
            // IRQ
            (cpu, mem) = make([0xF8, 0xEA], model: model)
            cpu.step(mem)
            cpu.p &= ~F.interruptDisable
            cpu.irqLine = true
            cpu.step(mem)
            XCTAssertEqual(cpu.p & F.decimal == 0, expectCleared, "\(model) IRQ")
            // NMI
            (cpu, mem) = make([0xF8, 0xEA], model: model)
            cpu.step(mem)
            cpu.triggerNMI()
            cpu.step(mem)
            XCTAssertEqual(cpu.p & F.decimal == 0, expectCleared, "\(model) NMI")
        }
    }

    func testResetClearsDecimal() {
        var (cpu, mem) = make([0xF8])
        cpu.step(mem)
        cpu.reset(mem)
        XCTAssertTrue(cpu.p & F.decimal == 0)
    }

    // MARK: 10進モード

    func testDecimalAddSetsNZFromResultAndTakesExtraCycle() {
        // SED; CLC; LDA #$99; ADC #$01 → $00、C=1、Z=1(NMOS は 2 進結果 $9A から Z=0)
        for (model, cycles, zero) in [(CPUModel.cmos65C02, 3, true), (CPUModel.nmos6502, 2, false)] {
            var (cpu, mem) = make([0xF8, 0x18, 0xA9, 0x99, 0x69, 0x01], model: model)
            for _ in 0..<3 { cpu.step(mem) }
            XCTAssertEqual(cpu.step(mem), cycles, "\(model)")
            XCTAssertEqual(cpu.a, 0x00)
            XCTAssertTrue(cpu.p & F.carry != 0)
            XCTAssertEqual(cpu.p & F.zero != 0, zero, "\(model) Z")
        }
        // 65C02: $50 + $50 = $00(C=1)。N は結果から決まり 0
        var (cpu, mem) = make([0xF8, 0x18, 0xA9, 0x50, 0x69, 0x50])
        for _ in 0..<4 { cpu.step(mem) }
        XCTAssertEqual(cpu.a, 0x00)
        XCTAssertTrue(cpu.p & F.carry != 0)
        XCTAssertTrue(cpu.p & F.zero != 0)
        XCTAssertTrue(cpu.p & F.negative == 0)
        // 結果の N: $45 + $45 = $90
        (cpu, mem) = make([0xF8, 0x18, 0xA9, 0x45, 0x69, 0x45])
        for _ in 0..<4 { cpu.step(mem) }
        XCTAssertEqual(cpu.a, 0x90)
        XCTAssertTrue(cpu.p & F.negative != 0)
        XCTAssertTrue(cpu.p & F.carry == 0)
    }

    func testDecimalSubtract() {
        // SED; SEC; LDA #$10; SBC #$20 → $90、借りあり(C=0)、N=1。1 サイクル追加
        var (cpu, mem) = make([0xF8, 0x38, 0xA9, 0x10, 0xE9, 0x20])
        for _ in 0..<3 { cpu.step(mem) }
        XCTAssertEqual(cpu.step(mem), 3)
        XCTAssertEqual(cpu.a, 0x90)
        XCTAssertTrue(cpu.p & F.carry == 0)
        XCTAssertTrue(cpu.p & F.negative != 0)
        // $46 - $12 = $34(C=1)
        (cpu, mem) = make([0xF8, 0x38, 0xA9, 0x46, 0xE9, 0x12])
        for _ in 0..<4 { cpu.step(mem) }
        XCTAssertEqual(cpu.a, 0x34)
        XCTAssertTrue(cpu.p & F.carry != 0)
        // $00 - $00 = $00 → Z=1
        (cpu, mem) = make([0xF8, 0x38, 0xA9, 0x00, 0xE9, 0x00])
        for _ in 0..<4 { cpu.step(mem) }
        XCTAssertTrue(cpu.p & F.zero != 0)
    }

    /// 65C02 の10進 SBC は、BCD として無効な入力でも Bruce Clark の付録 A の Seq.4 と一致する
    /// (全 131,072 通り: A、オペランド、キャリー)。C と V は2進結果から、N と Z は調整後の A から。
    func testDecimalSubtractMatchesClarkSeq4ForAllInputs() {
        for a in 0..<256 {
            for b in 0..<256 {
                for c in 0..<2 {
                    // SED; (SEC|CLC); LDA #a; SBC #b
                    var (cpu, mem) = make([0xF8, c == 1 ? 0x38 : 0x18, 0xA9, UInt8(a), 0xE9, UInt8(b)])
                    for _ in 0..<4 { cpu.step(mem) }
                    let al = (a & 0x0F) - (b & 0x0F) + c - 1
                    var r = a - b + c - 1
                    if r < 0 { r -= 0x60 }
                    if al < 0 { r -= 0x06 }
                    let expected = UInt8(truncatingIfNeeded: r)
                    let bin = a - b + c - 1
                    let binResult = UInt8(truncatingIfNeeded: bin)
                    let v = ((UInt8(a) ^ UInt8(b)) & (UInt8(a) ^ binResult) & 0x80) != 0
                    XCTAssertEqual(cpu.a, expected, "A: \(a) - \(b) c=\(c)")
                    XCTAssertEqual(cpu.p & F.carry != 0, bin >= 0, "C: \(a) - \(b) c=\(c)")
                    XCTAssertEqual(cpu.p & F.overflow != 0, v, "V: \(a) - \(b) c=\(c)")
                    XCTAssertEqual(cpu.p & F.zero != 0, expected == 0, "Z: \(a) - \(b) c=\(c)")
                    XCTAssertEqual(cpu.p & F.negative != 0, expected & 0x80 != 0, "N: \(a) - \(b) c=\(c)")
                    if cpu.a != expected { return }
                }
            }
        }
        // 例: $00 - $0A(C=0 → さらに 1 引く)は $8F。NMOS では $9F になる
        var (cpu, mem) = make([0xF8, 0x18, 0xA9, 0x00, 0xE9, 0x0A])
        for _ in 0..<4 { cpu.step(mem) }
        XCTAssertEqual(cpu.a, 0x8F)
    }

    func testBinaryAddHasNoExtraCycleOn65C02() {
        var (cpu, mem) = make([0x18, 0xA9, 0x01, 0x69, 0x01])
        for _ in 0..<2 { cpu.step(mem) }
        XCTAssertEqual(cpu.step(mem), 2)
    }

    // MARK: NOP と NMOS

    func testUndefinedOpcodesAreNOPsOn65C02() {
        func check(_ opcode: UInt8, length: Int, cycles: Int, file: StaticString = #filePath, line: UInt = #line) {
            var (cpu, mem) = make([opcode, 0x12, 0x34, 0xEA])
            cpu.a = 0x55
            let p = cpu.p
            XCTAssertEqual(cpu.step(mem), cycles, "opcode \(String(opcode, radix: 16))", file: file, line: line)
            XCTAssertEqual(Int(cpu.pc) - 0x200, length, "opcode \(String(opcode, radix: 16)) 長さ", file: file, line: line)
            XCTAssertEqual(cpu.a, 0x55, file: file, line: line)
            XCTAssertEqual(cpu.p, p, file: file, line: line)
            XCTAssertNil(cpu.lastIllegalOpcode, file: file, line: line)
        }
        for hi in 0..<16 {
            check(UInt8(hi * 16 + 0x3), length: 1, cycles: 1)
            if hi != 0xC && hi != 0xD { check(UInt8(hi * 16 + 0xB), length: 1, cycles: 1) }
        }
        for op: UInt8 in [0x02, 0x22, 0x42, 0x62, 0x82, 0xC2, 0xE2] { check(op, length: 2, cycles: 2) }
        check(0x44, length: 2, cycles: 3)
        for op: UInt8 in [0x54, 0xD4, 0xF4] { check(op, length: 2, cycles: 4) }
        check(0x5C, length: 3, cycles: 8)
        for op: UInt8 in [0xDC, 0xFC] { check(op, length: 3, cycles: 4) }
    }

    func testNoUndefinedOpcodesIn65C02Table() {
        XCTAssertTrue(CPU6502.table65C02.allSatisfy { $0.op != .illegal })
        XCTAssertEqual(CPU6502.table65C02.count, 256)
        // NMOS の公式命令は、65C02 でも同じ(JMP (abs) とシフト abs,X のサイクル、追加分を除く)
        let changed = (0..<256).filter {
            let n = CPU6502.table[$0], c = CPU6502.table65C02[$0]
            return n.op != .illegal && (n.op != c.op || n.mode != c.mode || n.cycles != c.cycles)
        }
        XCTAssertEqual(changed.sorted(), [0x1E, 0x3E, 0x5E, 0x6C, 0x7E])
    }

    func testNewOpcodesAreTwoCycleNOPsOnNMOS() {
        // 65C02 で追加された命令のオペコードは、NMOS では今までどおり 1 バイト 2 サイクルの未定義命令
        let added = (0..<256).filter { CPU6502.table[$0].op == .illegal }
        XCTAssertEqual(added.count, 256 - 151)
        for opcode in added {
            var (cpu, mem) = make([UInt8(opcode), 0x10, 0x00, 0xEA], model: .nmos6502)
            XCTAssertEqual(cpu.step(mem), 2, "opcode \(String(opcode, radix: 16))")
            XCTAssertEqual(cpu.pc, 0x0201)
            XCTAssertEqual(cpu.lastIllegalOpcode, UInt8(opcode))
            XCTAssertFalse(cpu.isWaiting || cpu.isStopped)
        }
    }

    func testDefaultModelIsNMOS() {
        XCTAssertEqual(CPU6502().model, .nmos6502)
        XCTAssertEqual(CPUModel(argument: "65C02"), .cmos65C02)
        XCTAssertEqual(CPUModel(argument: "6502"), .nmos6502)
        XCTAssertNil(CPUModel(argument: "z80"))
    }
}
