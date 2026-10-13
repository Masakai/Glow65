import Foundation
import XCTest
@testable import Glow65

final class TextTransferTests: XCTestCase {
    private func text(_ bytes: [UInt8]) -> String { String(decoding: bytes, as: UTF8.self) }

    func testLineEndsBecomeCR() {
        XCTAssertEqual(text(TextTransfer.bytes(from: "A\nB\r\nC\rD")), "A\rB\rC\rD")
        XCTAssertEqual(text(TextTransfer.bytes(from: "\n\n")), "\r\r")
        XCTAssertEqual(text(TextTransfer.bytes(from: "\r\n\r\n")), "\r\r")
    }

    func testTabsControlsAndNonASCII() {
        XCTAssertEqual(text(TextTransfer.bytes(from: "A\tB\u{07}C\u{7F}D")), "A BCD")
        XCTAssertEqual(text(TextTransfer.bytes(from: "é日")), "??")
    }

    func testEndWithNewline() {
        XCTAssertEqual(text(TextTransfer.bytes(from: "10 ?=1", endWithNewline: true)), "10 ?=1\r")
        XCTAssertEqual(text(TextTransfer.bytes(from: "10 ?=1\n", endWithNewline: true)), "10 ?=1\r")
        XCTAssertEqual(TextTransfer.bytes(from: "", endWithNewline: true), [])
        XCTAssertEqual(text(TextTransfer.bytes(from: "10 ?=1")), "10 ?=1")
    }

    func testFileWithCRLF() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("glow65-text-\(UUID().uuidString).txt")
        try Data("10 ?=1\r\n20 ?=2".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(text(try TextTransfer.bytes(contentsOf: url)), "10 ?=1\r20 ?=2\r")
    }
}
