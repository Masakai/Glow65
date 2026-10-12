import XCTest
@testable import Glow65

/// UART の受信キュー(順序、上限、大量の入力)。
final class UARTTests: XCTestCase {
    func testReceivesInOrderAndReportsPendingCount() {
        let uart = UART()
        for b in [UInt8(1), 2, 3] { uart.receive(b) }
        XCTAssertEqual(uart.pendingReceiveCount, 3)
        XCTAssertEqual([uart.readData(), uart.readData(), uart.readData()], [1, 2, 3])
        XCTAssertEqual(uart.pendingReceiveCount, 0)
        XCTAssertEqual(uart.readStatus() & UART.statusReceiveReady, 0)
        XCTAssertEqual(uart.readData(), 0)                  // 空のとき 0 を返し、受信数も増えない
        XCTAssertEqual(uart.receiveCount, 3)
    }

    func testDropsBytesBeyondTheQueueLimit() {
        let uart = UART()
        let limit = UART.receiveQueueLimit
        for i in 0..<(limit + 100) { uart.receive(UInt8(truncatingIfNeeded: i)) }
        XCTAssertEqual(uart.pendingReceiveCount, limit)     // 超えた分は捨てる
        XCTAssertEqual(uart.readData(), 0)                  // 先に届いた順に残っている
        XCTAssertEqual(uart.readData(), 1)
        uart.receive(0x55)                                  // 1 つ読んだので、1 つ入る
        XCTAssertEqual(uart.pendingReceiveCount, limit - 1)
    }

    func testLargeInputKeepsOrderAcrossCompaction() {
        let uart = UART()
        let n = 60_000
        for i in 0..<n { uart.receive(UInt8(truncatingIfNeeded: i)) }
        var mismatches = 0
        for i in 0..<n where uart.readData() != UInt8(truncatingIfNeeded: i) { mismatches += 1 }
        XCTAssertEqual(mismatches, 0)
        XCTAssertEqual(uart.pendingReceiveCount, 0)
    }

    func testMasterResetEmptiesTheQueueAfterPartialReads() {
        let uart = UART()
        for i in 0..<5000 { uart.receive(UInt8(truncatingIfNeeded: i)) }
        for _ in 0..<4500 { _ = uart.readData() }           // 詰め直しが起きる量
        uart.writeControl(0x03)
        XCTAssertEqual(uart.pendingReceiveCount, 0)
        uart.receive(0x42)
        XCTAssertEqual(uart.readData(), 0x42)
    }
}
