import Foundation

public enum ProgramLoadError: Error, CustomStringConvertible {
    case outOfRAM(address: UInt16, count: Int)
    case badSpec(String)
    case unreadable(String)
    case poweredOff

    public var description: String {
        switch self {
        case let .outOfRAM(address, count):
            return "RAM($0000-$7FFF)に収まらない: $\(String(address, radix: 16, uppercase: true)) から \(count) バイト"
        case let .badSpec(spec):
            return "書式は ファイル@16進アドレス(例: counter.bin@0300): \(spec)"
        case let .unreadable(path):
            return "ファイルを読めない: \(path)"
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
        let parts = spec.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let address = UInt16(parts[1].replacingOccurrences(of: "$", with: ""), radix: 16)
        else { throw ProgramLoadError.badSpec(spec) }
        return try load(path: parts[0], address: address)
    }

    public static func load(path: String, address: UInt16) throws -> ProgramImage {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw ProgramLoadError.unreadable(path)
        }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return ProgramImage(name: name, address: address, bytes: [UInt8](data))
    }
}
