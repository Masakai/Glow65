import Core6502

/// 本ボードのメモリマップ。
public enum MemoryMap {
    public static let ramSize = 0x8000          // $0000-$7FFF
    public static let uartBase: UInt16 = 0xA000  // $A000-$A0FF(下位1ビットで状態/データを選択)
    public static let uartEnd: UInt16 = 0xA0FF
    public static let romBase: UInt16 = 0xC000   // $C000-$FFFF
    public static let romSize = 0x4000
}

/// 本ボードのバス。RAM、UART、ROM を配置し、未割り当て領域は `$FF` を返す。
public final class SBCBus: Bus {
    public private(set) var ram: [UInt8]
    public private(set) var rom: [UInt8]
    public let uart: UART
    /// フロントパネル用のバス監視。nil のときは監視しない。
    public var probe: PanelProbe?

    public init(uart: UART = UART()) {
        self.uart = uart
        ram = [UInt8](repeating: 0, count: MemoryMap.ramSize)
        rom = [UInt8](repeating: 0xFF, count: MemoryMap.romSize)
    }

    @inline(__always)
    public func read(_ address: UInt16) -> UInt8 {
        let value = readValue(address)
        probe?.record(address: address, data: value, isWrite: false)
        return value
    }

    @inline(__always)
    private func readValue(_ address: UInt16) -> UInt8 {
        switch address {
        case 0x0000..<0x8000:
            return ram[Int(address)]
        case MemoryMap.uartBase...MemoryMap.uartEnd:
            return address & 1 == 0 ? uart.readStatus() : uart.readData()
        case MemoryMap.romBase...0xFFFF:
            return rom[Int(address - MemoryMap.romBase)]
        default:
            return 0xFF
        }
    }

    @inline(__always)
    public func write(_ address: UInt16, _ value: UInt8) {
        probe?.record(address: address, data: value, isWrite: true)
        switch address {
        case 0x0000..<0x8000:
            ram[Int(address)] = value
        case MemoryMap.uartBase...MemoryMap.uartEnd:
            if address & 1 == 0 {
                uart.writeControl(value)
            } else {
                uart.writeData(value)
            }
        default:
            break  // ROM と未割り当て領域への書き込みは無視
        }
    }

    /// ROM 領域にイメージを書き込む。`address` は CPU から見たアドレス($C000-$FFFF)。
    public func loadROM(_ image: [UInt8], at address: UInt16 = MemoryMap.romBase) {
        let offset = Int(address) - Int(MemoryMap.romBase)
        precondition(offset >= 0 && offset + image.count <= rom.count, "ROM 領域に収まらない")
        rom.replaceSubrange(offset..<(offset + image.count), with: image)
    }

    /// プログラムを RAM に書き込む。`address` から末尾までが RAM($0000-$7FFF)に収まる必要がある。
    public func loadRAM(_ bytes: [UInt8], at address: UInt16) throws {
        let start = Int(address)
        guard start + bytes.count <= MemoryMap.ramSize else {
            throw ProgramLoadError.outOfRAM(address: address, count: bytes.count)
        }
        ram.replaceSubrange(start..<(start + bytes.count), with: bytes)
    }

    /// 電源投入時の RAM をランダムに近い状態にするのではなく、0 で初期化する。
    public func clearRAM() {
        for i in ram.indices { ram[i] = 0 }
    }
}
