import Foundation
import XCTest
@testable import Glow65

/// `ProgramImage.load` の入力検査(書式、大きさ、ファイル名の @)。
final class ProgramImageTests: XCTestCase {
    private func temporaryFile(named name: String, bytes: [UInt8]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }

    func testRejectsFilesLargerThanTheAddressSpaceWithoutReadingThem() throws {
        let url = try temporaryFile(named: "big.bin", bytes: [UInt8](repeating: 0, count: 0x10001))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try ProgramImage.load(spec: "\(url.path)@0300")) { error in
            guard case ProgramLoadError.tooLarge(_, let size) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(size, 0x10001)
        }
    }

    func testAcceptsAFileOfExactlyTheAddressSpaceSize() throws {
        let url = try temporaryFile(named: "full.bin", bytes: [UInt8](repeating: 0xEA, count: 0x10000))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(try ProgramImage.load(spec: "\(url.path)@0000").bytes.count, 0x10000)
    }

    func testSplitsAtTheLastAtSignSoFileNamesMayContainOne() throws {
        let url = try temporaryFile(named: "my@prog.bin", bytes: [1, 2, 3])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let image = try ProgramImage.load(spec: "\(url.path)@0400")
        XCTAssertEqual(image.name, "my@prog.bin")
        XCTAssertEqual(image.address, 0x0400)
        XCTAssertEqual(image.bytes, [1, 2, 3])
    }

    func testRejectsMalformedSpecs() throws {
        let url = try temporaryFile(named: "p.bin", bytes: [1])
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        for spec in ["\(url.path)", "\(url.path)@", "\(url.path)@zz", "\(url.path)@10000", "@0300"] {
            XCTAssertThrowsError(try ProgramImage.load(spec: spec), spec) { error in
                guard case ProgramLoadError.badSpec = error else { return XCTFail("\(spec): \(error)") }
            }
        }
    }

    func testMissingFileIsUnreadable() {
        XCTAssertThrowsError(try ProgramImage.load(spec: "/nonexistent/file.bin@0300")) { error in
            guard case ProgramLoadError.unreadable = error else { return XCTFail("\(error)") }
        }
    }
}
