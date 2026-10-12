import Core6502

/// 本ボード全体(CPU、バス、UART)。
public final class Machine {
    public let bus: SBCBus
    public internal(set) var cpu = CPU6502()
    public private(set) var isPoweredOn = false

    public var uart: UART { bus.uart }

    public init(bus: SBCBus = SBCBus()) {
        self.bus = bus
    }

    /// 電源 ON。RAM を消去してリセットから始める。
    public func powerOn() {
        bus.clearRAM()
        uart.reset()
        isPoweredOn = true
        reset()
    }

    /// 電源 OFF。CPU は停止し、RAM の内容は失われる。
    public func powerOff() {
        isPoweredOn = false
        bus.clearRAM()
        uart.reset()
        cpu = CPU6502()
    }

    /// リセットボタン。RAM は保持し、リセットベクタから再開する。
    public func reset() {
        guard isPoweredOn else { return }
        cpu.reset(bus)
    }

    /// 1命令実行し、消費サイクルを返す。電源 OFF のときは 0。
    @discardableResult
    public func step() -> Int {
        guard isPoweredOn else { return 0 }
        // 割り込み受付でなければ、最初のバスアクセスは命令フェッチ(SYNC)
        cpu.irqLine = bus.uart.interruptRequest
        let servicesInterrupt = cpu.nmiPending
            || (cpu.irqLine && cpu.p & CPU6502.Flag.interruptDisable == 0)
        bus.probe?.syncPending = !servicesInterrupt
        return cpu.step(bus)
    }

    /// 少なくとも `cycles` サイクル分実行し、実際に消費したサイクル数を返す。
    @discardableResult
    public func run(cycles budget: Int) -> Int {
        guard isPoweredOn else { return 0 }
        var used = 0
        while used < budget {
            used += step()
        }
        return used
    }

    public func triggerNMI() {
        cpu.triggerNMI()
    }
}
