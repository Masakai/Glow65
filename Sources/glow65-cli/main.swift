import Darwin
import Foundation
import Core6502
import Glow65

// 使い方: glow65-cli [--rom ファイル@16進アドレス]... [--load ファイル@16進アドレス]... [--mhz N] [--cpu 6502|65c02]
// --load は電源投入後に RAM へ生のバイナリを書き込む(例: --load tutorial/counter.bin@0300)。
// 既定では ROM/monitor.bin を $F000、ROM/basic/build/basic.bin(あれば)を $C000、
// ROM/game65g.bin(あれば)を $8000 に読み込む。終了は Ctrl-\。

var romSpecs: [String] = []
var loadSpecs: [String] = []
var megahertz = 1.0
var cpuModel = CPUModel.nmos6502

let usage = "使い方: glow65-cli [--rom ファイル@16進アドレス]... [--load ファイル@16進アドレス]... [--mhz N] [--cpu 6502|65c02]"

/// 使い方の誤りを表示して、終了コード 2 で終わる。
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n\(usage)\n".utf8))
    exit(2)
}

var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "--rom":
        guard let spec = args.popFirst() else { fail("--rom にはファイル@アドレスを指定する") }
        romSpecs.append(spec)
    case "--load":
        guard let spec = args.popFirst() else { fail("--load にはファイル@アドレスを指定する") }
        loadSpecs.append(spec)
    case "--mhz":
        guard let value = args.popFirst(), let mhz = Double(value), mhz > 0 else {
            fail("--mhz には正の数を指定する")
        }
        megahertz = mhz
    case "--cpu":
        guard let value = args.popFirst(), let model = CPUModel(argument: value) else {
            FileHandle.standardError.write(Data("--cpu には 6502 または 65c02 を指定する\n\(usage)\n".utf8))
            exit(2)
        }
        cpuModel = model
    default:
        fail("不明なオプション: \(arg)")
    }
}
if romSpecs.isEmpty {
    romSpecs.append("ROM/monitor.bin@F000")
    if FileManager.default.fileExists(atPath: "ROM/basic/build/basic.bin") {
        romSpecs.append("ROM/basic/build/basic.bin@C000")
    }
    if FileManager.default.fileExists(atPath: "ROM/game65g.bin") {
        romSpecs.append("ROM/game65g.bin@8000")
    }
}

let machine = Machine(cpuModel: cpuModel)
for spec in romSpecs {
    do {
        let image = try ProgramImage.load(spec: spec)
        // ROM 領域($8000-$9FFF、$C000-$FFFF)に収まらないイメージは、クラッシュさせずに断る
        guard MemoryMap.romContains(address: image.address, count: image.bytes.count) else {
            FileHandle.standardError.write(Data("ROM 領域($8000-$9FFF、$C000-$FFFF)に収まらない: \(spec)\n".utf8))
            exit(1)
        }
        machine.bus.loadROM(image.bytes, at: image.address)
    } catch {
        FileHandle.standardError.write(Data("ROM を読めない: \(error)\n".utf8))
        exit(1)
    }
}

// 端末を raw モードにする
var original = termios()
tcgetattr(STDIN_FILENO, &original)
var raw = original
cfmakeraw(&raw)
raw.c_oflag |= tcflag_t(OPOST)  // 出力の改行変換は有効のまま
tcsetattr(STDIN_FILENO, TCSANOW, &raw)

func restoreTerminal() {
    tcsetattr(STDIN_FILENO, TCSANOW, &original)
}
atexit { restoreTerminal() }

/// 入力スレッドとメインスレッドの間で共有する終了フラグ(ロックで保護する)。
final class QuitFlag {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
let quit = QuitFlag()

// 入力スレッド: 端末から UART へ。Ctrl-\ (0x1C) で終了。
let inputThread = Thread {
    var byte: UInt8 = 0
    while read(STDIN_FILENO, &byte, 1) == 1 {
        if byte == 0x1C {
            quit.set()
            return
        }
        machine.uart.receive(byte)
    }
    quit.set()
}
inputThread.start()

machine.uart.onTransmit = { byte in
    var b = byte
    write(STDOUT_FILENO, &b, 1)
}

machine.powerOn()
for spec in loadSpecs {
    do {
        let image = try ProgramImage.load(spec: spec)
        try machine.bus.loadRAM(image.bytes, at: image.address)
    } catch {
        restoreTerminal()
        FileHandle.standardError.write(Data("プログラムを読み込めない: \(error)\n".utf8))
        exit(1)
    }
}

// 10ms 分ずつ実行して実時間に合わせる
let sliceSeconds = 0.01
let cyclesPerSlice = Int(megahertz * 1_000_000 * sliceSeconds)
var deadline = Date().timeIntervalSinceReferenceDate
while !quit.isSet {
    machine.run(cycles: cyclesPerSlice)
    deadline += sliceSeconds
    let wait = deadline - Date().timeIntervalSinceReferenceDate
    if wait > 0 {
        Thread.sleep(forTimeInterval: wait)
    } else if wait < -0.5 {
        deadline = Date().timeIntervalSinceReferenceDate  // 遅れすぎたら追いつきを諦める
    }
}
restoreTerminal()
print("\n電源断")
