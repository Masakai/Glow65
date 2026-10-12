/// 逆アセンブルした 1 命令。
public struct DisassembledInstruction: Equatable, Sendable {
    public let address: UInt16
    /// 命令のバイト列(オペコードとオペランド)。未定義のオペコードは 1 バイト。
    public let bytes: [UInt8]
    /// ニーモニック(大文字)。未定義のオペコードは `.BYTE`。
    public let mnemonic: String
    /// オペランドの文字列(例: `#$00`、`$03F0,X`、`($12),Y`)。なければ空。
    public let operand: String

    public var length: Int { bytes.count }

    /// `AAAA  BB BB BB  MNEMON OPERAND` の形(モニタの `L` コマンドと同じ並び)。
    public var line: String {
        let hex = bytes.map { Self.hex($0, 2) }.joined(separator: " ")
        let padded = hex + String(repeating: " ", count: max(0, 8 - hex.count))
        let text = operand.isEmpty ? mnemonic : mnemonic + " " + operand
        return "\(Self.hex(address, 4))  \(padded) \(text)"
    }

    static func hex<T: BinaryInteger>(_ value: T, _ width: Int) -> String {
        let s = String(value, radix: 16, uppercase: true)
        return String(repeating: "0", count: max(0, width - s.count)) + s
    }
}

/// 6502 の逆アセンブラ。命令表は CPU コアと同じ(`CPU6502.table`、65C02 は `CPU6502.table65C02`)。
public enum Disassembler {
    /// `address` の命令を読み解く。`read` は副作用のない読み出しを渡す
    /// (I/O を読むと状態が変わるため、`peek` のようなものを使う)。
    /// `model` が 65C02 のときは、追加の命令とモードも読み解く。
    public static func disassemble(
        at address: UInt16, model: CPUModel = .nmos6502, read: (UInt16) -> UInt8
    ) -> DisassembledInstruction {
        let opcode = read(address)
        let info = (model == .cmos65C02 ? CPU6502.table65C02 : CPU6502.table)[Int(opcode)]
        if info.op == .illegal {
            return DisassembledInstruction(
                address: address, bytes: [opcode], mnemonic: ".BYTE",
                operand: "$" + DisassembledInstruction.hex(opcode, 2))
        }
        let length: Int
        switch info.mode {
        case .implied, .accumulator: length = 1
        case .absolute, .absoluteX, .absoluteY, .indirect, .absoluteIndexedIndirect, .zeroPageRelative: length = 3
        default: length = 2
        }
        var bytes = [opcode]
        for i in 1..<max(length, 1) { bytes.append(read(address &+ UInt16(i))) }
        let b1 = bytes.count > 1 ? bytes[1] : 0
        let b2 = bytes.count > 2 ? bytes[2] : 0
        let hex2 = { (v: UInt8) in "$" + DisassembledInstruction.hex(v, 2) }
        let abs = "$" + DisassembledInstruction.hex(UInt16(b2) << 8 | UInt16(b1), 4)
        let operand: String
        switch info.mode {
        case .implied: operand = ""
        case .accumulator: operand = "A"
        case .immediate: operand = "#" + hex2(b1)
        case .zeroPage: operand = hex2(b1)
        case .zeroPageX: operand = hex2(b1) + ",X"
        case .zeroPageY: operand = hex2(b1) + ",Y"
        case .absolute: operand = abs
        case .absoluteX: operand = abs + ",X"
        case .absoluteY: operand = abs + ",Y"
        case .indirect: operand = "(" + abs + ")"
        case .indexedIndirect: operand = "(" + hex2(b1) + ",X)"
        case .indirectIndexed: operand = "(" + hex2(b1) + "),Y"
        case .relative:
            let target = UInt16(truncatingIfNeeded: Int(address) + 2 + Int(Int8(bitPattern: b1)))
            operand = "$" + DisassembledInstruction.hex(target, 4)
        case .zeroPageIndirect: operand = "(" + hex2(b1) + ")"
        case .absoluteIndexedIndirect: operand = "(" + abs + ",X)"
        case .zeroPageRelative:
            let target = UInt16(truncatingIfNeeded: Int(address) + 3 + Int(Int8(bitPattern: b2)))
            operand = hex2(b1) + ",$" + DisassembledInstruction.hex(target, 4)
        }
        var mnemonic = String(describing: info.op).uppercased()
        switch info.op {
        case .rmb, .smb, .bbr, .bbs: mnemonic += String((opcode >> 4) & 7)
        default: break
        }
        return DisassembledInstruction(address: address, bytes: bytes, mnemonic: mnemonic, operand: operand)
    }
}
