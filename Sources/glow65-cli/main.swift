import Darwin
import Foundation
import Glow65

// 使い方: glow65-cli [--rom ファイル@16進アドレス]... [--mhz N]
// 既定では ROM/monitor.bin を $F000、ROM/basic/build/basic.bin(あれば)を $C000 に読み込む。終了は Ctrl-\。

var romSpecs: [(path: String, address: UInt16)] = []
var megahertz = 1.0

var args = CommandLine.arguments.dropFirst()
while let arg = args.popFirst() {
    switch arg {
    case "--rom":
        guard let spec = args.popFirst() else { fatalError("--rom にはファイル@アドレスを指定する") }
        let parts = spec.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2, let address = UInt16(parts[1], radix: 16) else {
            fatalError("--rom の書式は ファイル@16進アドレス: \(spec)")
        }
        romSpecs.append((parts[0], address))
    case "--mhz":
        guard let value = args.popFirst(), let mhz = Double(value), mhz > 0 else {
            fatalError("--mhz には正の数を指定する")
        }
        megahertz = mhz
    default:
        fatalError("不明なオプション: \(arg)")
    }
}
if romSpecs.isEmpty {
    romSpecs.append(("ROM/monitor.bin", 0xF000))
    if FileManager.default.fileExists(atPath: "ROM/basic/build/basic.bin") {
        romSpecs.append(("ROM/basic/build/basic.bin", 0xC000))
    }
}

let machine = Machine()
for spec in romSpecs {
    guard let data = FileManager.default.contents(atPath: spec.path) else {
        FileHandle.standardError.write(Data("ROM を読めない: \(spec.path)\n".utf8))
        exit(1)
    }
    machine.bus.loadROM([UInt8](data), at: spec.address)
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

var quit = false

// 入力スレッド: 端末から UART へ。Ctrl-\ (0x1C) で終了。
let inputThread = Thread {
    var byte: UInt8 = 0
    while read(STDIN_FILENO, &byte, 1) == 1 {
        if byte == 0x1C {
            quit = true
            return
        }
        machine.uart.receive(byte)
    }
    quit = true
}
inputThread.start()

machine.uart.onTransmit = { byte in
    var b = byte
    write(STDOUT_FILENO, &b, 1)
}

machine.powerOn()

// 10ms 分ずつ実行して実時間に合わせる
let sliceSeconds = 0.01
let cyclesPerSlice = Int(megahertz * 1_000_000 * sliceSeconds)
var deadline = Date().timeIntervalSinceReferenceDate
while !quit {
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
