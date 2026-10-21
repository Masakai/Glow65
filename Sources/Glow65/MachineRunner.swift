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
    /// モニタの G で RAM のプログラムを起動したときに切り替える速度。nil なら切り替えない。
    private var goSpeed: SpeedSetting?
    /// G で切り替える前の速度。G で起動したプログラムの実行中だけ値を持つ。
    private var speedBeforeGo: SpeedSetting?

    /// モニタ ROM の中で、G の切り替えに使う番地(ROM/monitor.lst)。
    enum MonitorHook {
        /// CMD_G の `@call: JMP (VAL)`。飛び先は VAL($F4/$F5)にある。
        static let goJump: UInt16 = 0xF23B
        static let goJumpBytes: [UInt8] = [0x6C, 0xF4, 0x00]
        /// CMDLOOP(プロンプトを出すところ)。RTS で戻ったとき、RESET のあとはここを通る。
        static let commandLoop: UInt16 = 0xF154
        static let commandLoopBytes: [UInt8] = [0xA9, 0x2A]  // LDA #'*'
    }

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
            leaveGoSpeed()
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
            leaveGoSpeed()
            resetTiming()
            instantAccess = nil
            publish()
        }
    }

    public func reset() {
        queue.async { [self] in
            machine.reset()
            leaveGoSpeed()
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
            // G の実行中に手で変えたら、モニタに戻っても元の速度には戻さない
            speedBeforeGo = nil
            switchSpeed(to: newSpeed)
            publish()
        }
    }

    /// モニタの G で RAM($0000-$7FFF)のプログラムを起動したときの速度。nil なら切り替えない。
    ///
    /// プロンプトに戻ると(RTS、RESET)、G の前の速度に戻す。
    public func setGoSpeed(_ newSpeed: SpeedSetting?) {
        queue.async { [self] in goSpeed = newSpeed }
    }

    /// 停止中に1命令進める。
    public func step() {
        queue.async { [self] in
            guard machine.isPoweredOn, !isRunning else { return }
            if pending != nil {
                finishPending()
            } else {
                prepareProbeForStepping()
                checkMonitorHooks()
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
            } else {
                checkMonitorHooks()
                if let p = beginInstruction() {
                    pending = p
                    instantAccess = p.accesses[0]
                    if p.accesses.count == 1 {
                        pending = nil
                    }
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

    /// 速度を変える。持ち越しのサイクルは捨てる。
    private func switchSpeed(to newSpeed: SpeedSetting) {
        if !newSpeed.showsEveryCycle { finishPending() }
        speed = newSpeed
        credit = 0
    }

    /// G で切り替えた速度を、G の前の速度に戻す。
    private func leaveGoSpeed() {
        guard let before = speedBeforeGo else { return }
        speedBeforeGo = nil
        switchSpeed(to: before)
    }

    /// 命令ごとにモニタの番地を見張る必要があるか。
    private var watchesMonitorHooks: Bool {
        (goSpeed != nil || speedBeforeGo != nil) && monitorHooksAvailable
    }

    /// 載っているモニタ ROM が、`MonitorHook` の番地を使える版か。
    private var monitorHooksAvailable: Bool {
        func matches(_ address: UInt16, _ bytes: [UInt8]) -> Bool {
            bytes.indices.allSatisfy { machine.bus.peek(address &+ UInt16($0)) == bytes[$0] }
        }
        return matches(MonitorHook.goJump, MonitorHook.goJumpBytes)
            && matches(MonitorHook.commandLoop, MonitorHook.commandLoopBytes)
    }

    /// 次に実行する命令が G の飛び先へのジャンプか、プロンプトなら、速度を切り替える。
    /// 速度を変えたら true。
    @discardableResult
    private func checkMonitorHooks() -> Bool {
        let pc = machine.cpu.pc
        guard pc == MonitorHook.goJump || pc == MonitorHook.commandLoop, monitorHooksAvailable else {
            return false
        }
        if pc == MonitorHook.commandLoop {
            guard speedBeforeGo != nil else { return false }
            leaveGoSpeed()
            return true
        }
        let target = UInt16(machine.bus.peek(0x00F4)) | UInt16(machine.bus.peek(0x00F5)) << 8
        // ROM の飛び先(GAME65G の G 8003 など)は対象にしない
        guard let goSpeed, speedBeforeGo == nil, Int(target) < MemoryMap.ramSize else { return false }
        speedBeforeGo = speed
        guard goSpeed != speed else { return false }
        switchSpeed(to: goSpeed)
        return true
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
        instantAccess = nil
        guard watchesMonitorHooks else {
            credit -= Double(machine.run(cycles: Int(credit)))
            return
        }
        // G の切り替えを見張るときは 1 命令ずつ。速度が変わったら、残りの持ち時間は捨てる
        let budget = Int(credit)
        var used = 0
        while used < budget {
            if checkMonitorHooks() { return }
            used += machine.step()
        }
        credit -= Double(used)
    }

    /// 低速実行: 命令を実行しては、そのバスアクセスを時間をかけて1つずつ表示する。
    private func advanceReplay() {
        while credit > 0 {
            if pending == nil {
                // 速度が変わったら、この回はここまで(全速になったら次からは runFast)
                if checkMonitorHooks() { break }
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
