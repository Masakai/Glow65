/// CPU の種類。
public enum CPUModel: Sendable, Equatable, CaseIterable {
    /// NMOS 6502(公式命令のみ。未定義命令は2サイクルの NOP)。
    case nmos6502
    /// 65C02。WDC W65C02S 相当(基本の65C02、Rockwell/WDC 拡張の BBR/BBS/RMB/SMB、WAI/STP)。
    case cmos65C02

    /// 表示用の名前(`6502`、`65C02`)。
    public var displayName: String {
        switch self {
        case .nmos6502: return "6502"
        case .cmos65C02: return "65C02"
        }
    }

    /// `--cpu` の引数(`6502`、`65c02`。大文字小文字は問わない)から種類を得る。
    public init?(argument: String) {
        switch argument.lowercased() {
        case "6502": self = .nmos6502
        case "65c02": self = .cmos65C02
        default: return nil
        }
    }
}

/// 6502 系の CPU コア(NMOS 6502 と 65C02。公式命令、10進モード、割り込みを実装)。
///
/// - 1回の `step` で1命令を実行し、消費したサイクル数を返す。
/// - NMOS では未定義命令を2サイクルの NOP として扱い、`lastIllegalOpcode` に記録する。
///   65C02 には未定義命令がなく、すべて NOP として実行する。
/// - リード・モディファイ・ライト命令の中間書き込み(ダミーライト)と、
///   インデックス補正時のダミーリードは再現しない。
public struct CPU6502 {
    // MARK: ステータスフラグ

    public struct Flag {
        public static let carry: UInt8 = 0x01
        public static let zero: UInt8 = 0x02
        public static let interruptDisable: UInt8 = 0x04
        public static let decimal: UInt8 = 0x08
        public static let `break`: UInt8 = 0x10
        public static let unused: UInt8 = 0x20
        public static let overflow: UInt8 = 0x40
        public static let negative: UInt8 = 0x80
    }

    // MARK: レジスタ

    public var a: UInt8 = 0
    public var x: UInt8 = 0
    public var y: UInt8 = 0
    public var sp: UInt8 = 0xFD
    public var pc: UInt16 = 0
    /// ステータスレジスタ。bit5 は常に1、bit4(B)は内部では保持しない。
    public var p: UInt8 = Flag.unused | Flag.interruptDisable

    // MARK: 状態

    /// リセット後の累計サイクル数。
    public var cycles: UInt64 = 0
    /// NMI の立ち下がりエッジを受け付けた状態。次の `step` で処理される。
    public var nmiPending = false
    /// IRQ 線の状態(レベルトリガ)。true の間、I フラグが0なら割り込みを受け付ける。
    public var irqLine = false
    /// 最後に実行した未定義命令のオペコード。
    public var lastIllegalOpcode: UInt8?
    /// CPU の種類。既定は NMOS 6502。
    public var model: CPUModel = .nmos6502
    /// WAI で割り込みを待っている(65C02)。NMI または IRQ 線で再開する。
    public private(set) var isWaiting = false
    /// STP で停止している(65C02)。リセットまで再開しない。
    public private(set) var isStopped = false

    public init() {}

    public init(model: CPUModel) {
        self.model = model
    }

    // MARK: 割り込み・リセット

    public mutating func reset<B: Bus>(_ bus: B) {
        a = 0
        x = 0
        y = 0
        sp = 0xFD
        p = Flag.unused | Flag.interruptDisable
        nmiPending = false
        isWaiting = false
        isStopped = false
        pc = read16(bus, 0xFFFC)
        cycles = 7
    }

    /// NMI 線の立ち下がりを通知する。
    public mutating func triggerNMI() {
        nmiPending = true
    }

    // MARK: 実行

    /// 1命令(または1回の割り込み受付)を実行し、消費サイクル数を返す。
    @discardableResult
    public mutating func step<B: Bus>(_ bus: B) -> Int {
        // STP/WAI の待機中は1サイクルを消費し、バスにはアクセスしない。
        if isStopped {
            cycles &+= 1
            return 1
        }
        if isWaiting {
            // I フラグが立っていても再開する(その場合は割り込みを受け付けず、次の命令へ進む)
            guard nmiPending || irqLine else {
                cycles &+= 1
                return 1
            }
            isWaiting = false
        }
        if nmiPending {
            nmiPending = false
            interrupt(bus, vector: 0xFFFA, isBreak: false)
            cycles &+= 7
            return 7
        }
        if irqLine && (p & Flag.interruptDisable) == 0 {
            interrupt(bus, vector: 0xFFFE, isBreak: false)
            cycles &+= 7
            return 7
        }

        let opcode = fetch(bus)
        let cmos = model == .cmos65C02
        let inst = (cmos ? Self.table65C02 : Self.table)[Int(opcode)]
        var count = Int(inst.cycles)

        // 実効アドレスの解決
        var addr: UInt16 = 0
        var crossed = false
        switch inst.mode {
        case .implied, .accumulator:
            break
        case .immediate:
            addr = pc
            pc &+= 1
        case .zeroPage:
            addr = UInt16(fetch(bus))
        case .zeroPageX:
            addr = UInt16(fetch(bus) &+ x)
        case .zeroPageY:
            addr = UInt16(fetch(bus) &+ y)
        case .absolute:
            addr = fetch16(bus)
        case .absoluteX:
            let base = fetch16(bus)
            addr = base &+ UInt16(x)
            crossed = (base ^ addr) & 0xFF00 != 0
        case .absoluteY:
            let base = fetch16(bus)
            addr = base &+ UInt16(y)
            crossed = (base ^ addr) & 0xFF00 != 0
        case .indirect:
            let ptr = fetch16(bus)
            // NMOS の JMP (xxFF) バグ: 上位バイトは同一ページの先頭から読む
            // 65C02 では修正され、上位バイトは ptr+1 から読む
            let hiAddr = cmos ? ptr &+ 1 : (ptr & 0xFF00) | UInt16(UInt8(truncatingIfNeeded: ptr) &+ 1)
            addr = UInt16(bus.read(ptr)) | UInt16(bus.read(hiAddr)) << 8
        case .indexedIndirect:
            let zp = fetch(bus) &+ x
            addr = UInt16(bus.read(UInt16(zp))) | UInt16(bus.read(UInt16(zp &+ 1))) << 8
        case .indirectIndexed:
            let zp = fetch(bus)
            let base = UInt16(bus.read(UInt16(zp))) | UInt16(bus.read(UInt16(zp &+ 1))) << 8
            addr = base &+ UInt16(y)
            crossed = (base ^ addr) & 0xFF00 != 0
        case .relative:
            break
        case .zeroPageIndirect:
            let zp = fetch(bus)
            addr = UInt16(bus.read(UInt16(zp))) | UInt16(bus.read(UInt16(zp &+ 1))) << 8
        case .absoluteIndexedIndirect:
            let ptr = fetch16(bus) &+ UInt16(x)
            addr = read16(bus, ptr)
        case .zeroPageRelative:
            addr = UInt16(fetch(bus))  // ゼロページのアドレス。相対オフセットは命令の中で読む
        }

        switch inst.op {
        // ロード/ストア
        case .lda: a = load(bus, addr); setNZ(a)
        case .ldx: x = load(bus, addr); setNZ(x)
        case .ldy: y = load(bus, addr); setNZ(y)
        case .sta: bus.write(addr, a)
        case .stx: bus.write(addr, x)
        case .sty: bus.write(addr, y)

        // レジスタ間転送
        case .tax: x = a; setNZ(x)
        case .tay: y = a; setNZ(y)
        case .txa: a = x; setNZ(a)
        case .tya: a = y; setNZ(a)
        case .tsx: x = sp; setNZ(x)
        case .txs: sp = x

        // スタック
        case .pha: push(bus, a)
        case .php: push(bus, p | Flag.break | Flag.unused)
        case .pla: a = pull(bus); setNZ(a)
        case .plp: p = (pull(bus) & ~Flag.break) | Flag.unused

        // 論理演算
        case .and: a &= load(bus, addr); setNZ(a)
        case .ora: a |= load(bus, addr); setNZ(a)
        case .eor: a ^= load(bus, addr); setNZ(a)
        case .bit:
            let m = bus.read(addr)
            setFlag(Flag.zero, (a & m) == 0)
            // 65C02 の BIT #imm は Z だけを変える
            if inst.mode != .immediate {
                setFlag(Flag.negative, m & 0x80 != 0)
                setFlag(Flag.overflow, m & 0x40 != 0)
            }

        // 算術演算
        case .adc:
            adc(load(bus, addr))
            if cmos && p & Flag.decimal != 0 { count += 1 }
        case .sbc:
            sbc(load(bus, addr))
            if cmos && p & Flag.decimal != 0 { count += 1 }
        case .cmp: compare(a, load(bus, addr))
        case .cpx: compare(x, load(bus, addr))
        case .cpy: compare(y, load(bus, addr))

        // インクリメント/デクリメント
        case .inc:
            if inst.mode == .accumulator {
                a &+= 1
                setNZ(a)
            } else {
                let v = bus.read(addr) &+ 1
                bus.write(addr, v)
                setNZ(v)
            }
        case .dec:
            if inst.mode == .accumulator {
                a &-= 1
                setNZ(a)
            } else {
                let v = bus.read(addr) &- 1
                bus.write(addr, v)
                setNZ(v)
            }
        case .inx: x &+= 1; setNZ(x)
        case .iny: y &+= 1; setNZ(y)
        case .dex: x &-= 1; setNZ(x)
        case .dey: y &-= 1; setNZ(y)

        // シフト/ローテート
        case .asl, .lsr, .rol, .ror:
            modify(bus, inst.op, inst.mode, addr)

        // ジャンプ/サブルーチン
        case .jmp:
            pc = addr
        case .jsr:
            // JSR は戻り番地として「次の命令 - 1」を積む
            let ret = pc &- 1
            push(bus, UInt8(ret >> 8))
            push(bus, UInt8(truncatingIfNeeded: ret))
            pc = addr
        case .rts:
            let lo = UInt16(pull(bus))
            let hi = UInt16(pull(bus))
            pc = ((hi << 8) | lo) &+ 1
        case .rti:
            p = (pull(bus) & ~Flag.break) | Flag.unused
            let lo = UInt16(pull(bus))
            let hi = UInt16(pull(bus))
            pc = (hi << 8) | lo
        case .brk:
            pc &+= 1
            interrupt(bus, vector: 0xFFFE, isBreak: true)

        // 分岐
        case .bcc: count += branch(bus, p & Flag.carry == 0)
        case .bcs: count += branch(bus, p & Flag.carry != 0)
        case .beq: count += branch(bus, p & Flag.zero != 0)
        case .bne: count += branch(bus, p & Flag.zero == 0)
        case .bmi: count += branch(bus, p & Flag.negative != 0)
        case .bpl: count += branch(bus, p & Flag.negative == 0)
        case .bvc: count += branch(bus, p & Flag.overflow == 0)
        case .bvs: count += branch(bus, p & Flag.overflow != 0)

        // フラグ操作
        case .clc: p &= ~Flag.carry
        case .sec: p |= Flag.carry
        case .cli: p &= ~Flag.interruptDisable
        case .sei: p |= Flag.interruptDisable
        case .cld: p &= ~Flag.decimal
        case .sed: p |= Flag.decimal
        case .clv: p &= ~Flag.overflow

        // 65C02 の追加命令
        case .bra: count += branch(bus, true)
        case .phx: push(bus, x)
        case .phy: push(bus, y)
        case .plx: x = pull(bus); setNZ(x)
        case .ply: y = pull(bus); setNZ(y)
        case .stz: bus.write(addr, 0)
        case .trb:
            let m = bus.read(addr)
            setFlag(Flag.zero, (a & m) == 0)
            bus.write(addr, m & ~a)
        case .tsb:
            let m = bus.read(addr)
            setFlag(Flag.zero, (a & m) == 0)
            bus.write(addr, m | a)
        case .rmb:
            bus.write(addr, bus.read(addr) & ~(1 << UInt8((opcode >> 4) & 7)))
        case .smb:
            bus.write(addr, bus.read(addr) | (1 << UInt8((opcode >> 4) & 7)))
        case .bbr:
            let bit = bus.read(addr) & (1 << UInt8((opcode >> 4) & 7))
            count += branch(bus, bit == 0)
        case .bbs:
            let bit = bus.read(addr) & (1 << UInt8((opcode >> 4) & 7))
            count += branch(bus, bit != 0)
        case .wai: isWaiting = true
        case .stp: isStopped = true

        case .nop:
            break
        case .illegal:
            lastIllegalOpcode = opcode
        }

        // ページ跨ぎによる1サイクル加算(読み出し命令のみ)
        // 65C02 ではシフト/ローテート abs,X も、ページ跨ぎで1サイクル加算される
        if crossed && (inst.op.addsCycleOnPageCross || (cmos && inst.op.isShift)) {
            count += 1
        }

        cycles &+= UInt64(count)
        return count
    }

    // MARK: バスアクセス補助

    @inline(__always)
    private mutating func fetch<B: Bus>(_ bus: B) -> UInt8 {
        let v = bus.read(pc)
        pc &+= 1
        return v
    }

    @inline(__always)
    private mutating func fetch16<B: Bus>(_ bus: B) -> UInt16 {
        let lo = UInt16(fetch(bus))
        let hi = UInt16(fetch(bus))
        return (hi << 8) | lo
    }

    @inline(__always)
    private func read16<B: Bus>(_ bus: B, _ address: UInt16) -> UInt16 {
        UInt16(bus.read(address)) | UInt16(bus.read(address &+ 1)) << 8
    }

    @inline(__always)
    private func load<B: Bus>(_ bus: B, _ address: UInt16) -> UInt8 {
        bus.read(address)
    }

    @inline(__always)
    private mutating func push<B: Bus>(_ bus: B, _ value: UInt8) {
        bus.write(0x0100 | UInt16(sp), value)
        sp &-= 1
    }

    @inline(__always)
    private mutating func pull<B: Bus>(_ bus: B) -> UInt8 {
        sp &+= 1
        return bus.read(0x0100 | UInt16(sp))
    }

    // MARK: フラグ補助

    @inline(__always)
    private mutating func setFlag(_ flag: UInt8, _ on: Bool) {
        if on { p |= flag } else { p &= ~flag }
    }

    @inline(__always)
    private mutating func setNZ(_ value: UInt8) {
        setFlag(Flag.zero, value == 0)
        setFlag(Flag.negative, value & 0x80 != 0)
    }

    // MARK: 命令の共通処理

    private mutating func compare(_ reg: UInt8, _ m: UInt8) {
        setFlag(Flag.carry, reg >= m)
        setNZ(reg &- m)
    }

    /// アキュムレータまたはメモリに対するシフト/ローテート。
    private mutating func modify<B: Bus>(
        _ bus: B, _ op: Operation, _ mode: AddressingMode, _ addr: UInt16
    ) {
        if mode == .accumulator {
            a = shift(op, a)
            setNZ(a)
        } else {
            let v = shift(op, bus.read(addr))
            bus.write(addr, v)
            setNZ(v)
        }
    }

    private mutating func shift(_ op: Operation, _ v: UInt8) -> UInt8 {
        let carryIn = p & Flag.carry
        switch op {
        case .asl:
            setFlag(Flag.carry, v & 0x80 != 0)
            return v << 1
        case .lsr:
            setFlag(Flag.carry, v & 0x01 != 0)
            return v >> 1
        case .rol:
            setFlag(Flag.carry, v & 0x80 != 0)
            return (v << 1) | carryIn
        default:  // .ror
            setFlag(Flag.carry, v & 0x01 != 0)
            return (v >> 1) | (carryIn << 7)
        }
    }

    /// 分岐命令。追加サイクル数(成立1、ページ跨ぎでさらに1)を返す。
    private mutating func branch<B: Bus>(_ bus: B, _ condition: Bool) -> Int {
        let offset = Int8(bitPattern: fetch(bus))
        guard condition else { return 0 }
        let target = pc &+ UInt16(bitPattern: Int16(offset))
        let extra = (target ^ pc) & 0xFF00 != 0 ? 2 : 1
        pc = target
        return extra
    }

    private mutating func interrupt<B: Bus>(_ bus: B, vector: UInt16, isBreak: Bool) {
        push(bus, UInt8(pc >> 8))
        push(bus, UInt8(truncatingIfNeeded: pc))
        var status = p | Flag.unused
        if isBreak { status |= Flag.break } else { status &= ~Flag.break }
        push(bus, status)
        p |= Flag.interruptDisable
        if model == .cmos65C02 { p &= ~Flag.decimal }
        pc = read16(bus, vector)
    }

    // MARK: 加減算(10進モード対応)

    private mutating func adc(_ m: UInt8) {
        let carry = Int(p & Flag.carry)
        let binary = Int(a) + Int(m) + carry
        if p & Flag.decimal == 0 {
            setFlag(Flag.carry, binary > 0xFF)
            setFlag(Flag.overflow, (~(a ^ m) & (a ^ UInt8(truncatingIfNeeded: binary)) & 0x80) != 0)
            a = UInt8(truncatingIfNeeded: binary)
            setNZ(a)
            return
        }
        // NMOS の10進加算。Z は2進結果、N/V は上位調整前の中間値から決まる。
        // 65C02 は N と Z を調整後の結果から決める(V は NMOS と同じ中間値の規則。Klaus のテストは
        // 10進モードの V を判定しないので、この規則は実測では確認していない)。
        var low = Int(a & 0x0F) + Int(m & 0x0F) + carry
        if low >= 0x0A {
            low = ((low + 0x06) & 0x0F) + 0x10
        }
        var sum = Int(a & 0xF0) + Int(m & 0xF0) + low
        if model == .nmos6502 {
            setFlag(Flag.zero, binary & 0xFF == 0)
            setFlag(Flag.negative, sum & 0x80 != 0)
        }
        setFlag(
            Flag.overflow,
            (~(a ^ m) & (a ^ UInt8(truncatingIfNeeded: sum)) & 0x80) != 0
        )
        if sum >= 0xA0 {
            sum += 0x60
        }
        setFlag(Flag.carry, sum >= 0x100)
        a = UInt8(truncatingIfNeeded: sum)
        if model == .cmos65C02 { setNZ(a) }
    }

    private mutating func sbc(_ m: UInt8) {
        let carry = Int(p & Flag.carry)
        let binary = Int(a) - Int(m) - (1 - carry)
        let result = UInt8(truncatingIfNeeded: binary)
        // NMOS では N、Z、C、V が10進モードでも2進結果から決まる。
        setFlag(Flag.carry, binary >= 0)
        setFlag(Flag.overflow, ((a ^ m) & (a ^ result) & 0x80) != 0)
        setNZ(result)
        if p & Flag.decimal == 0 {
            a = result
            return
        }
        if model == .cmos65C02 {
            // 65C02 の10進 SBC(Bruce Clark の付録 A の Seq.4): 全体を2進で引いてから、
            // 結果が負なら $60、下位桁が借りたなら $06 を引く。
            let lowDiff = Int(a & 0x0F) - Int(m & 0x0F) + carry - 1
            var diff = Int(a) - Int(m) + carry - 1
            if diff < 0 { diff -= 0x60 }
            if lowDiff < 0 { diff -= 0x06 }
            a = UInt8(truncatingIfNeeded: diff)
            setNZ(a)
            return
        }
        var low = Int(a & 0x0F) - Int(m & 0x0F) + carry - 1
        if low < 0 {
            low = ((low - 0x06) & 0x0F) - 0x10
        }
        var diff = Int(a & 0xF0) - Int(m & 0xF0) + low
        if diff < 0 {
            diff -= 0x60
        }
        a = UInt8(truncatingIfNeeded: diff)
    }
}
