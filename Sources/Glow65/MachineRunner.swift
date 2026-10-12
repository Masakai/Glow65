import Core6502
import Foundation

/// `Machine` を専用スレッドで実時間に合わせて動かし、フロントパネル用の状態を公開する。
///
/// スイッチ類(電源、リセット、RUN/STOP、STEP、SPEED)の操作は、どのスレッドからでも呼べる。
/// 実際の処理は内部の直列キュー上で行われる。
public final class MachineRunner {
    public let machine: Machine

    private let probe = PanelProbe()
    private let queue = DispatchQueue(label: "glow65.runner", qos: .userInteractive)
    private var timer: DispatchSourceTimer?

    private let lock = NSLock()
    private var published = PanelSnapshot()

    // 以下は queue 上でのみ読み書きする
    private var isRunning = true
    private var speed = SpeedSetting.mhz1
    private var credit = 0.0
    private var lastTick = DispatchTime.now()
    private var pending: PendingInstruction?
    private var instantAccess: BusAccess?

    private struct Registers {
        var a: UInt8, x: UInt8, y: UInt8, sp: UInt8, pc: UInt16, p: UInt8
    }

    /// 低速・ステップ実行中に、1サイクルずつ表示しているところの命令。
    private struct PendingInstruction {
        var accesses: [BusAccess]
        var cycles: Int
        var consumed: Double
        var index: Int
        var before: Registers
    }

    public init(machine: Machine = Machine()) {
        self.machine = machine
        machine.bus.probe = probe
    }

    public convenience init(cpuModel: CPUModel) {
        self.init(machine: Machine(cpuModel: cpuModel))
    }

    /// 実行ループを開始する。
    public func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            lastTick = .now()
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now(), repeating: .milliseconds(10), leeway: .milliseconds(1))
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            timer = t
            publish()
        }
    }

    public func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
        }
    }

    /// 最新のパネル状態。
    public var snapshot: PanelSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return published
    }

    // MARK: スイッチ

    public func powerOn() {
        queue.async { [self] in
            machine.powerOn()
            isRunning = true
            resetTiming()
            instantAccess = probe.lastAccess
            publish()
        }
    }

    /// CPU の種類を切り替える。電源が入っているときは何もしない。
    public func setCPUModel(_ model: CPUModel) {
        queue.async { [self] in
            guard machine.setCPUModel(model) else { return }
            publish()
        }
    }

    public func powerOff() {
        queue.async { [self] in
            machine.powerOff()
            resetTiming()
            instantAccess = nil
            publish()
        }
    }

    public func reset() {
        queue.async { [self] in
            machine.reset()
            resetTiming()
            instantAccess = probe.lastAccess
            publish()
        }
    }

    public func setRunning(_ running: Bool) {
        queue.async { [self] in
            if !running {
                finishPending()
                if pending == nil, instantAccess == nil, machine.isPoweredOn {
                    instantAccess = probe.lastAccess
                }
            }
            isRunning = running
            credit = 0
            lastTick = .now()
            publish()
        }
    }

    public func setSpeed(_ newSpeed: SpeedSetting) {
        queue.async { [self] in
            if !newSpeed.showsEveryCycle { finishPending() }
            speed = newSpeed
            credit = 0
            publish()
        }
    }

    /// 停止中に1命令進める。
    public func step() {
        queue.async { [self] in
            guard machine.isPoweredOn, !isRunning else { return }
            if pending != nil {
                finishPending()
            } else {
                prepareProbeForStepping()
                machine.step()
                instantAccess = probe.lastAccess
            }
            publish()
        }
    }

    /// 停止中に1サイクル(バスアクセス1回分)進める。
    public func stepCycle() {
        queue.async { [self] in
            guard machine.isPoweredOn, !isRunning else { return }
            if var p = pending {
                p.index += 1
                if p.index >= p.accesses.count {
                    pending = nil
                    instantAccess = p.accesses.last
                } else {
                    pending = p
                    instantAccess = p.accesses[p.index]
                }
            } else if let p = beginInstruction() {
                pending = p
                instantAccess = p.accesses[0]
                if p.accesses.count == 1 {
                    pending = nil
                }
            }
            publish()
        }
    }

    public func triggerNMI() {
        queue.async { [self] in machine.triggerNMI() }
    }

    /// プログラムを RAM に読み込む(電源が入っているときだけ)。結果は `completion` に返る。
    ///
    /// 電源投入で RAM が消去されるため、電源を入れた後に呼ぶ。CPU の実行は止めない。
    public func loadProgram(_ image: ProgramImage, completion: @escaping (Result<Void, ProgramLoadError>) -> Void) {
        queue.async { [self] in
            guard machine.isPoweredOn else {
                completion(.failure(.poweredOff))
                return
            }
            do {
                try machine.bus.loadRAM(image.bytes, at: image.address)
                completion(.success(()))
            } catch let error as ProgramLoadError {
                completion(.failure(error))
            } catch {
                completion(.failure(.unreadable(image.name)))
            }
        }
    }

    /// キーボード入力を UART へ送る。
    public func sendInput(_ byte: UInt8) {
        machine.uart.receive(byte)
    }

    /// テスト用: 実時間を待たずに `seconds` 秒ぶん進める。
    func advanceForTesting(seconds: Double) {
        queue.sync { advance(elapsed: seconds) }
    }

    /// テスト用: キュー上の処理がすべて終わるまで待つ。
    func drainForTesting() {
        queue.sync {}
    }

    // MARK: 実行

    private func resetTiming() {
        credit = 0
        pending = nil
        lastTick = .now()
    }

    private func prepareProbeForStepping() {
        probe.accumulatesGlow = false
        probe.recordsAccesses = false
    }

    private func tick() {
        let now = DispatchTime.now()
        let elapsed = Double(now.uptimeNanoseconds &- lastTick.uptimeNanoseconds) / 1e9
        lastTick = now
        advance(elapsed: elapsed)
    }

    /// 実時間 `elapsed` 秒ぶんだけ進める。
    private func advance(elapsed: Double) {
        guard machine.isPoweredOn, isRunning else {
            publish()
            return
        }
        credit += min(elapsed, 0.1) * speed.hertz
        if speed.showsEveryCycle {
            advanceReplay()
        } else {
            runFast()
        }
        publish()
    }

    private func runFast() {
        probe.accumulatesGlow = true
        probe.recordsAccesses = false
        guard credit >= 1 else { return }
        let used = machine.run(cycles: Int(credit))
        credit -= Double(used)
        instantAccess = nil
    }

    /// 低速実行: 命令を実行しては、そのバスアクセスを時間をかけて1つずつ表示する。
    private func advanceReplay() {
        while credit > 0 {
            if pending == nil {
                guard let p = beginInstruction() else { break }
                pending = p
            }
            guard var p = pending else { break }
            let remaining = Double(p.cycles) - p.consumed
            let take = min(credit, remaining)
            p.consumed += take
            credit -= take
            let count = p.accesses.count
            p.index = min(Int(p.consumed / Double(p.cycles) * Double(count)), count - 1)
            instantAccess = p.accesses[p.index]
            pending = p.consumed >= Double(p.cycles) ? nil : p
        }
    }

    /// 次の命令を実行してバスアクセス列を得る。CPU の状態は即座に更新される。
    private func beginInstruction() -> PendingInstruction? {
        guard machine.isPoweredOn else { return nil }
        let before = registers()
        probe.accumulatesGlow = false
        probe.recordsAccesses = true
        probe.clearAccesses()
        let cycles = machine.step()
        probe.recordsAccesses = false
        var accesses = probe.accesses
        if accesses.isEmpty { accesses = [probe.lastAccess] }
        return PendingInstruction(
            accesses: accesses, cycles: max(cycles, 1), consumed: 0, index: 0, before: before
        )
    }

    /// 途中まで表示した命令を完了扱いにする。
    private func finishPending() {
        if let p = pending {
            instantAccess = p.accesses.last
        }
        pending = nil
    }

    private func registers() -> Registers {
        let c = machine.cpu
        return Registers(a: c.a, x: c.x, y: c.y, sp: c.sp, pc: c.pc, p: c.p)
    }

    // MARK: 公開用の状態

    private func publish() {
        var s = PanelSnapshot()
        s.isPoweredOn = machine.isPoweredOn
        s.isRunning = isRunning
        s.speed = speed
        s.cpuModel = machine.cpuModel
        guard machine.isPoweredOn else {
            lock.lock()
            published = s
            lock.unlock()
            return
        }

        let regs = pending?.before ?? registers()
        s.a = regs.a
        s.x = regs.x
        s.y = regs.y
        s.sp = regs.sp
        s.pc = regs.pc
        s.instruction = Disassembler.disassemble(at: regs.pc, model: machine.cpuModel, read: machine.bus.peek)
        s.isWaiting = machine.cpu.isWaiting
        s.isStopped = machine.cpu.isStopped
        s.status = regs.p
        s.irqLine = machine.cpu.irqLine
        s.nmiPending = machine.cpu.nmiPending
        s.cycles = machine.cpu.cycles
        s.uartTransmitCount = machine.uart.transmitCount
        s.uartReceiveCount = machine.uart.receiveCount

        if let access = instantAccess {
            for i in 0..<16 { s.address[i] = access.address >> UInt16(i) & 1 == 1 ? 1 : 0 }
            for i in 0..<8 { s.data[i] = access.data >> UInt8(i) & 1 == 1 ? 1 : 0 }
            s.writeLevel = access.isWrite ? 1 : 0
            s.readLevel = access.isWrite ? 0 : 1
            s.syncLevel = access.isSync ? 1 : 0
        } else if probe.accumulatesGlow {
            let levels = probe.takeLevels()
            if levels.accessCount > 0 {
                s.address = levels.address
                s.data = levels.data
                s.readLevel = levels.read
                s.writeLevel = levels.write
                s.syncLevel = levels.sync
            } else {
                lock.lock()
                let previous = published
                lock.unlock()
                s.address = previous.address
                s.data = previous.data
                s.readLevel = previous.readLevel
                s.writeLevel = previous.writeLevel
                s.syncLevel = previous.syncLevel
            }
        }
        lock.lock()
        published = s
        lock.unlock()
    }
}
