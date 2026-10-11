import AppKit
import Foundation
import Glow65
import SwiftUI

/// フロントパネルの表示状態とスイッチ操作の窓口。
///
/// 60Hz で `MachineRunner` のスナップショットを読み、LED の明るさに残光(減衰)を付けて公開する。
@MainActor
final class PanelModel: ObservableObject {
    let runner: MachineRunner
    let terminal = TerminalModel()

    // 表示用の LED の明るさ(0...1)。添字はビット番号(0 = LSB)。
    @Published private(set) var address = [Double](repeating: 0, count: 16)
    @Published private(set) var data = [Double](repeating: 0, count: 8)
    @Published private(set) var pc = [Double](repeating: 0, count: 16)
    @Published private(set) var sp = [Double](repeating: 0, count: 8)
    @Published private(set) var a = [Double](repeating: 0, count: 8)
    @Published private(set) var x = [Double](repeating: 0, count: 8)
    @Published private(set) var y = [Double](repeating: 0, count: 8)
    @Published private(set) var status = [Double](repeating: 0, count: 8)
    @Published private(set) var readLED = 0.0
    @Published private(set) var writeLED = 0.0
    @Published private(set) var syncLED = 0.0
    @Published private(set) var runLED = 0.0
    @Published private(set) var haltLED = 0.0
    @Published private(set) var irqLED = 0.0
    @Published private(set) var nmiLED = 0.0
    @Published private(set) var txLED = 0.0
    @Published private(set) var rxLED = 0.0
    @Published private(set) var cycleCount: UInt64 = 0

    // スイッチの状態
    @Published var isPowerOn = false
    @Published var isRunSwitchOn = true
    @Published var stepsByCycle = false
    @Published var speed = SpeedSetting.mhz1
    @Published private(set) var romError: String?
    /// プログラムの読み込み結果など、短い案内。
    @Published private(set) var statusMessage: String?
    /// `--load` で指定されたプログラム。電源を入れるたびに RAM へ読み込む。
    private var launchPrograms: [ProgramImage] = []

    private var timer: Timer?
    private var lastTx: UInt64 = 0
    private var lastRx: UInt64 = 0
    private var lastFrame = Date()

    init() {
        runner = MachineRunner()
        runner.machine.uart.onTransmit = { [terminal] byte in terminal.enqueue(byte) }
        loadROM()
        runner.start()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.frame() }
        }
        applyLaunchArguments()
    }

    /// 動作確認と画面収録用の起動オプション。
    ///
    /// - `--power-on`: 起動直後に電源を入れる。
    /// - `--power-on-after <秒>`: 指定の秒数後に電源を入れる。
    /// - `--input <文字列>`: 文字列を入力する(`\r` は CR)。既定では起動の 1 秒後に一括で送る。
    /// - `--input-after <秒>`: 入力を始めるまでの秒数。
    /// - `--type-delay <秒>`: 1 文字ごとの間隔(指定すると打鍵のように 1 文字ずつ送る)。
    private func applyLaunchArguments() {
        let args = CommandLine.arguments
        func value(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        for (i, arg) in args.enumerated() where arg == "--load" && i + 1 < args.count {
            do {
                launchPrograms.append(try ProgramImage.load(spec: args[i + 1]))
            } catch {
                statusMessage = "Could not load \(args[i + 1]): \(error)"
            }
        }
        if args.contains("--power-on") { setPower(true) }
        if let seconds = value("--power-on-after").flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                self?.setPower(true)
            }
        }
        if let raw = value("--input") {
            let text = raw.replacingOccurrences(of: "\\r", with: "\r")
            let start = value("--input-after").flatMap(Double.init) ?? 1.0
            let delay = value("--type-delay").flatMap(Double.init) ?? 0
            for (index, byte) in text.utf8.enumerated() {
                let when = start + delay * Double(index)
                DispatchQueue.main.asyncAfter(deadline: .now() + when) { [weak self] in
                    self?.typed(byte)
                }
            }
        }
    }

    // MARK: ROM

    private func loadROM() {
        guard let url = Self.findROM("ROM/monitor.bin") else {
            romError = "ROM/monitor.bin が見つからない。Tools/build_monitor.sh を実行する。"
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            romError = "ROM を読めない: \(url.path)"
            return
        }
        runner.machine.bus.loadROM([UInt8](data), at: 0xF000)
        // BASIC は任意(なければモニタだけで動く)
        if let basicURL = Self.findROM("ROM/basic/build/basic.bin"),
           let basic = try? Data(contentsOf: basicURL) {
            runner.machine.bus.loadROM([UInt8](basic), at: 0xC000)
        } else {
            romError = "BASIC ROM(ROM/basic/build/basic.bin)がない。Tools/build_basic.sh で生成する。"
        }
    }

    private static func findROM(_ relativePath: String) -> URL? {
        var candidates: [URL] = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
        var dir = Bundle.main.executableURL?.deletingLastPathComponent()
        for _ in 0..<6 {
            if let d = dir {
                candidates.append(d)
                dir = d.deletingLastPathComponent()
            }
        }
        for base in candidates {
            let url = base.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    // MARK: スイッチ操作

    func setPower(_ on: Bool) {
        isPowerOn = on
        if on {
            terminal.clear()
            isRunSwitchOn = true
            statusMessage = nil
            runner.powerOn()
            launchPrograms.forEach(load)
        } else {
            runner.powerOff()
        }
    }

    // MARK: プログラムの読み込み

    /// プログラムを RAM に読み込む。電源が入っているときだけ受け付ける。
    func load(_ image: ProgramImage) {
        guard isPowerOn else {
            statusMessage = "Power is off. Flip POWER on first (powering on clears RAM), then load the program."
            return
        }
        runner.loadProgram(image) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    let addr = String(image.address, radix: 16, uppercase: true).leftPadded(to: 4)
                    self?.statusMessage = "Loaded \(image.name) (\(image.bytes.count) bytes) at $\(addr). In the monitor, type G \(addr) to run it."
                case .failure(.outOfRAM):
                    self?.statusMessage = "\(image.name) does not fit in RAM ($0000-$7FFF) at that address."
                case .failure(.poweredOff):
                    self?.statusMessage = "Power is off. Flip POWER on first, then load the program."
                case .failure:
                    self?.statusMessage = "Could not load \(image.name)."
                }
            }
        }
    }

    /// ファイル選択パネルを開き、選んだバイナリを指定アドレスに読み込む。
    func presentLoadPanel() {
        let panel = NSOpenPanel()
        panel.title = "Load Program"
        panel.message = "Choose a raw binary (for example one built with Tools/assemble.sh)."
        panel.prompt = "Load"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        let label = NSTextField(labelWithString: "Load at $")
        let field = NSTextField(string: "0300")
        field.frame.size.width = 70
        let stack = NSStackView(views: [label, field])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        panel.accessoryView = stack
        panel.isAccessoryViewDisclosed = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let address = UInt16(field.stringValue.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "$", with: ""), radix: 16) else {
            statusMessage = "\"\(field.stringValue)\" is not a hexadecimal address."
            return
        }
        do {
            load(try ProgramImage.load(path: url.path, address: address))
        } catch {
            statusMessage = "Could not read \(url.lastPathComponent)."
        }
    }

    func pressReset() {
        guard isPowerOn else { return }
        runner.reset()
    }

    func setRun(_ on: Bool) {
        isRunSwitchOn = on
        runner.setRunning(on)
    }

    func pressStep() {
        guard isPowerOn, !isRunSwitchOn else { return }
        if stepsByCycle { runner.stepCycle() } else { runner.step() }
    }

    func setSpeed(_ s: SpeedSetting) {
        speed = s
        runner.setSpeed(s)
    }

    func typed(_ byte: UInt8) {
        guard isPowerOn else { return }
        runner.sendInput(byte)
    }

    // MARK: 表示更新

    /// 点灯は即座に、消灯はゆるやかに減衰させて、残光を表現する。
    private func glow(_ shown: [Double], _ target: [Double], decay: Double) -> [Double] {
        var out = shown
        for i in out.indices {
            let t = i < target.count ? target[i] : 0
            out[i] = t >= shown[i] ? t : max(t, shown[i] * decay)
        }
        return out
    }

    private func glow(_ shown: Double, _ target: Double, decay: Double) -> Double {
        target >= shown ? target : max(target, shown * decay)
    }

    private func bits(_ value: UInt16, count: Int) -> [Double] {
        (0..<count).map { value >> UInt16($0) & 1 == 1 ? 1 : 0 }
    }

    private func frame() {
        terminal.flush()
        let now = Date()
        let dt = now.timeIntervalSince(lastFrame)
        lastFrame = now
        // 約 50ms で 1/e に減衰
        let decay = exp(-dt / 0.05)

        let s = runner.snapshot
        if s.isPoweredOn != isPowerOn && !s.isPoweredOn { isPowerOn = false }
        cycleCount = s.cycles

        guard s.isPoweredOn else {
            // 電源 OFF は瞬時に消灯
            let off16 = [Double](repeating: 0, count: 16)
            let off8 = [Double](repeating: 0, count: 8)
            address = off16; pc = off16
            data = off8; sp = off8; a = off8; x = off8; y = off8; status = off8
            readLED = 0; writeLED = 0; syncLED = 0; runLED = 0; haltLED = 0
            irqLED = 0; nmiLED = 0; txLED = 0; rxLED = 0
            return
        }

        address = glow(address, s.address, decay: decay)
        data = glow(data, s.data, decay: decay)
        pc = glow(pc, bits(s.pc, count: 16), decay: decay)
        sp = glow(sp, bits(UInt16(s.sp), count: 8), decay: decay)
        a = glow(a, bits(UInt16(s.a), count: 8), decay: decay)
        x = glow(x, bits(UInt16(s.x), count: 8), decay: decay)
        y = glow(y, bits(UInt16(s.y), count: 8), decay: decay)
        status = glow(status, bits(UInt16(s.status | 0x20), count: 8), decay: decay)
        readLED = glow(readLED, s.readLevel, decay: decay)
        writeLED = glow(writeLED, s.writeLevel, decay: decay)
        syncLED = glow(syncLED, s.syncLevel, decay: decay)
        runLED = glow(runLED, s.isRunning ? 1 : 0, decay: decay)
        haltLED = glow(haltLED, s.isRunning ? 0 : 1, decay: decay)
        irqLED = glow(irqLED, s.irqLine ? 1 : 0, decay: decay)
        nmiLED = glow(nmiLED, s.nmiPending ? 1 : 0, decay: decay)
        let tx = s.uartTransmitCount
        let rx = s.uartReceiveCount
        txLED = glow(txLED, tx != lastTx ? 1 : 0, decay: decay)
        rxLED = glow(rxLED, rx != lastRx ? 1 : 0, decay: decay)
        lastTx = tx
        lastRx = rx
    }
}

private extension String {
    func leftPadded(to width: Int) -> String {
        String(repeating: "0", count: max(0, width - count)) + self
    }
}
