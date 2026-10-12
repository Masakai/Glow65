import Foundation

public enum ProgramLoadError: Error, CustomStringConvertible {
    case outOfRAM(address: UInt16, count: Int)
    case badSpec(String)
    case unreadable(String)
    case tooLarge(String, size: Int)
    case poweredOff

    public var description: String {
        switch self {
        case let .outOfRAM(address, count):
            return "RAM($0000-$7FFF)に収まらない: $\(String(address, radix: 16, uppercase: true)) から \(count) バイト"
        case let .badSpec(spec):
            return "書式は ファイル@16進アドレス(例: counter.bin@0300): \(spec)"
        case let .unreadable(path):
            return "ファイルを読めない: \(path)"
        case let .tooLarge(path, size):
            return "ファイルが大きすぎる(\(size) バイト。アドレス空間は 65,536 バイト): \(path)"
        case .poweredOff:
            return "電源が入っていない(電源を入れると RAM が消去されるため、先に電源を入れる)"
        }
    }
}

/// RAM に読み込むプログラム(生のバイナリ)と、読み込み先のアドレス。
public struct ProgramImage {
    public let name: String
    public let address: UInt16
    public let bytes: [UInt8]

    public init(name: String, address: UInt16, bytes: [UInt8]) {
        self.name = name
        self.address = address
        self.bytes = bytes
    }

    /// `ファイル@16進アドレス` を読み、ファイルの中身を取り込む。
    public static func load(spec: String) throws -> ProgramImage {
        // ファイル名に @ を含んでもよいように、最後の @ で分ける
        guard let at = spec.lastIndex(of: "@") else { throw ProgramLoadError.badSpec(spec) }
        let path = String(spec[..<at])
        let addressText = spec[spec.index(after: at)...].replacingOccurrences(of: "$", with: "")
        guard !path.isEmpty, let address = UInt16(addressText, radix: 16)
        else { throw ProgramLoadError.badSpec(spec) }
        return try load(path: path, address: address)
    }

    public static func load(path: String, address: UInt16) throws -> ProgramImage {
        // 読み込む前に大きさを調べる(アドレス空間より大きいファイルは、メモリに読まずに断る)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = (attributes[.size] as? NSNumber)?.intValue
        else { throw ProgramLoadError.unreadable(path) }
        guard size <= 0x10000 else { throw ProgramLoadError.tooLarge(path, size: size) }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw ProgramLoadError.unreadable(path)
        }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return ProgramImage(name: name, address: address, bytes: [UInt8](data))
    }
}
