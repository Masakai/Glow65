import Foundation
import XCTest
@testable import Glow65
@testable import Core6502

/// examples/startrek.gam を GAME65G で動かす。乱数の種はキーを押すまでの時間で決まるので、
/// テストでは同じサイクル数で押して、毎回同じ銀河にする。
final class StarTrekExampleTests: XCTestCase {
    final class Output {
        var bytes: [UInt8] = []
        var text: String { String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\r", with: "") }
    }

    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardized
    }

    func makeGame(model: CPUModel = .nmos6502) throws -> (Machine, Output) {
        guard let mon = try? Data(contentsOf: root().appendingPathComponent("ROM/monitor.bin")),
              let game = try? Data(contentsOf: root().appendingPathComponent("ROM/game65g.bin")) else {
            throw XCTSkip("monitor.bin または game65g.bin がない")
        }
        let machine = Machine(cpuModel: model)
        machine.bus.loadROM([UInt8](mon), at: 0xF000)
        machine.bus.loadROM([UInt8](game), at: 0x8000)
        let out = Output()
        machine.uart.onTransmit = { out.bytes.append($0) }
        machine.powerOn()
        machine.run(cycles: 50_000)
        for b in "t\r".utf8 { machine.uart.receive(b) }
        machine.run(cycles: 200_000)
        let program = try TextTransfer.bytes(contentsOf: root().appendingPathComponent("examples/startrek.gam"))
        for b in program { machine.uart.receive(b) }
        machine.run(cycles: 60_000_000)
        return (machine, out)
    }

    func send(_ m: Machine, _ text: String, cycles: Int = 20_000_000) {
        for b in text.utf8 { m.uart.receive(b) }
        m.run(cycles: cycles)
    }

    /// ゲームを始め、最初のコマンドの入力待ちまで進める。
    func startGame(model: CPUModel = .nmos6502) throws -> (Machine, Output) {
        let (m, out) = try makeGame(model: model)
        XCTAssertFalse(out.text.contains("\nERR"), out.text)
        out.bytes.removeAll()
        send(m, "#=1\r", cycles: 2_000_000)
        send(m, " ", cycles: 30_000_000)
        XCTAssertTrue(out.text.hasSuffix("COMMAND (0=HELP)? "), out.text)
        return (m, out)
    }

    /// Ctrl-C で止め、直接実行で状況を作ってから、主ループ(300 行)に戻る。
    /// Enterprise をセクター 1,1 に置き、セクターの地図を空にする。
    func setUp(_ m: Machine, _ statements: [String]) {
        send(m, "\u{03}", cycles: 1_000_000)
        send(m, "I=0,63 S:I)=0 @=I+1 X=0 Y=0 S:0)=1 Z(12)=0 Z(13)=0 Z(15)=0 I=0,8 K(I)=0 @=I+1\r", cycles: 5_000_000)
        for line in statements { send(m, line + "\r", cycles: 2_000_000) }
        send(m, "#=300\r", cycles: 5_000_000)
    }

    /// 決まった銀河で、航行(衝突と象限の移動)、シールド、コンピュータ、魚雷、フェイザー、降伏までを通す。
    func testScriptedGame() throws {
        let (m, out) = try startGame()
        XCTAssertTrue(out.text.contains("DESTROY THE 15 KLINGON WARSHIPS"), out.text)
        XCTAssertTrue(out.text.contains("NOW ENTERING CANOPUS III QUADRANT"), out.text)
        for input in ["6\r500\r", "1\r6\r1\r", "1\r7\r1\r", "8\r2\r",
                      "5\r6.8\u{08}7\r", "1\r5\r1\r", "4\r200\r", "3\r", "8\r0\r", "8\r1\r", "8\r5\r",
                      "9\r", "n"] {
            send(m, input)
        }
        let text = out.text
        XCTAssertFalse(text.contains("\nERR"), text)
        XCTAssertTrue(text.contains("SHIELDS NOW AT 500 UNITS"), text)
        XCTAssertTrue(text.contains("WARP ENGINES SHUT DOWN AT SECTOR 6,4 DUE TO BAD NAVIGATION"), text)
        XCTAssertTrue(text.contains("NOW ENTERING ALTAIR III QUADRANT"), text)
        XCTAssertTrue(text.contains("DIRECTION = 6.7\n   DISTANCE  = 4.1"), text)
        XCTAssertTrue(text.contains("PHOTON TORPEDO COURSE (1-9)? 6.8\u{08} \u{08}7\nTORPEDO TRACK:"), text)
        XCTAssertTrue(text.contains("               5,8\n*** KLINGON DESTROYED ***"), text)
        XCTAssertTrue(text.contains("UNIT HIT ON KLINGON AT SECTOR 7,7\n*** KLINGON DESTROYED ***"), text)
        XCTAssertTrue(text.contains(" 6   008   002   002   ***"), text)        // 銀河の記録(倒した分が減っている)
        XCTAssertTrue(text.contains("KLINGONS LEFT: 13"), text)
        XCTAssertTrue(text.contains("  SAGITTARIUS"), text)                      // 領域名の地図
        XCTAssertTrue(text.contains("THERE WERE 13 KLINGON BATTLE CRUISERS LEFT AT"), text)
        XCTAssertTrue(text.hasSuffix("PLAY AGAIN (Y/N)? n\n>"), text)
    }

    /// クリンゴンの反撃でシールドが尽きると、Enterprise は撃沈される。
    func testKlingonsDestroyTheEnterprise() throws {
        let (m, out) = try startGame()
        setUp(m, ["S:2)=2 K(0)=2 K(1)=0 K(2)=300 Z(12)=1 H=0"])
        out.bytes.removeAll()
        send(m, "4\r10\r")
        let text = out.text
        XCTAssertTrue(text.contains("UNIT HIT ON ENTERPRISE FROM SECTOR 3,1"), text)
        XCTAssertTrue(text.contains("THE ENTERPRISE HAS BEEN DESTROYED."), text)
        XCTAssertTrue(text.hasSuffix("PLAY AGAIN (Y/N)? "), text)
        XCTAssertFalse(text.contains("\nERR"), text)
    }

    /// 最後のクリンゴンを魚雷で倒すと勝ちになり、効率の評価が出る。65C02 でも動く。
    func testWinWithLastTorpedo() throws {
        for model in [CPUModel.nmos6502, .cmos65C02] {
            let (m, out) = try startGame(model: model)
            setUp(m, ["S:3)=2 K(0)=3 K(1)=0 K(2)=200 Z(12)=1 Z(6)=1 Z(7)=10 T=50"])
            out.bytes.removeAll()
            send(m, "5\r1\r")
            let text = out.text
            XCTAssertTrue(text.contains("TORPEDO TRACK:\n               2,1\n               3,1\n               4,1\n*** KLINGON DESTROYED ***"), "\(model) " + text)
            XCTAssertTrue(text.contains("CONGRATULATIONS, CAPTAIN!"), text)
            XCTAssertTrue(text.contains("YOUR EFFICIENCY RATING IS 4000"), text)   // 1000 x (10 隻 / 5.0 日)^2
        }
    }

    /// 宇宙基地の隣に入るとドッキングし、補給と、時間を使った修理ができる。
    func testDockingRefuelsAndRepairs() throws {
        let (m, out) = try startGame()
        setUp(m, ["X=0 Y=2 S:0)=0 S:16)=1 S:1)=3 Z(13)=1 Z(16)=1 Z(17)=0 E=1000 Z(2)=3 H=100 D(0)=-15 D(3)=-5 T=0"])
        out.bytes.removeAll()
        send(m, "1\r3\r0.2\r")
        send(m, "7\ry")
        let text = out.text
        XCTAssertTrue(text.contains("SHIELDS DROPPED FOR DOCKING PURPOSES"), text)
        XCTAssertTrue(text.contains("CONDITION          DOCKED"), text)
        XCTAssertTrue(text.contains("TOTAL ENERGY       3000"), text)
        XCTAssertTrue(text.contains("PHOTON TORPEDOES   10"), text)
        // 0.2 の航行の間に 0.2 ずつ直っている
        XCTAssertTrue(text.contains("WARP ENGINES        -1.3\n"), text)
        XCTAssertTrue(text.contains("PHASER CONTROL      -0.3\n"), text)
        XCTAssertTrue(text.contains("WILL YOU AUTHORIZE THE REPAIR ORDER (Y/N)? y"), text)
        XCTAssertTrue(text.hasSuffix("WARP ENGINES         0.0\nSHORT RANGE SENSORS  0.0\nLONG RANGE SENSORS   0.0\n"
            + "PHASER CONTROL       0.0\nPHOTON TUBES         0.0\nDAMAGE CONTROL       0.0\nSHIELD CONTROL       0.0\n"
            + "LIBRARY-COMPUTER     0.0\n\nCOMMAND (0=HELP)? "), text)
        XCTAssertFalse(text.contains("\nERR"), text)
    }
}
