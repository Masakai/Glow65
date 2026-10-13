import Core6502
import Glow65
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 部品

/// 1個の LED。`level`(0...1)で明るさが変わる。
struct LEDView: View {
    let level: Double
    var color: Color = Color(red: 1.0, green: 0.12, blue: 0.08)
    var size: CGFloat = 15

    var body: some View {
        Circle()
            .fill(color.opacity(0.14 + 0.86 * level))
            .overlay(Circle().stroke(Color.black.opacity(0.55), lineWidth: 1))
            .overlay(
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.55 * level), .clear],
                        center: .init(x: 0.38, y: 0.34), startRadius: 0, endRadius: size * 0.5))
            )
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.9 * level), radius: 7 * level)
    }
}

/// ラベル付きの LED 列。`levels` の添字はビット番号(0 = LSB)で、左が最上位ビット。
struct LEDRow: View {
    let title: String
    let levels: [Double]
    var group = 4
    var bitLabels: [String]?
    var color: Color = Color(red: 1.0, green: 0.12, blue: 0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PanelStyle.label)
                .fixedSize()
            HStack(spacing: 0) {
                ForEach(Array((0..<levels.count).reversed()), id: \.self) { bit in
                    VStack(spacing: 2) {
                        LEDView(level: levels[bit], color: color)
                        Text(bitLabels?[bit] ?? "\(bit)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(PanelStyle.label.opacity(0.8))
                    }
                    .frame(width: 22)
                    .padding(.trailing, (bit % group == 0 && bit != 0) ? 9 : 0)
                }
            }
        }
    }
}

struct SingleLED: View {
    let title: String
    let level: Double
    var color: Color = Color(red: 1.0, green: 0.12, blue: 0.08)

    var body: some View {
        VStack(spacing: 3) {
            LEDView(level: level, color: color)
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(PanelStyle.label)
        }
        .frame(width: 44)
    }
}

/// 上下に倒すトグルスイッチ(電源、RUN/STOP など)。
struct ToggleSwitch: View {
    let title: String
    let upLabel: String
    let downLabel: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(upLabel).font(.system(size: 8, design: .monospaced)).foregroundStyle(PanelStyle.label)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color(white: 0.08), Color(white: 0.22)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 56)
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 14, height: 24)
                    .offset(y: isOn ? -14 : 14)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: isOn ? 2 : -2)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeOut(duration: 0.08)) { isOn.toggle() } }
            Text(downLabel).font(.system(size: 8, design: .monospaced)).foregroundStyle(PanelStyle.label)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(PanelStyle.label)
        }
        .frame(width: 76)
    }
}

/// 押している間だけ作動するスイッチ(RESET、STEP)。
struct MomentarySwitch: View {
    let title: String
    let action: () -> Void
    @State private var isDown = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color(white: 0.08), Color(white: 0.22)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 56)
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 14, height: 24)
                    .offset(y: isDown ? 10 : -4)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isDown {
                        isDown = true
                        action()
                    }
                }
                .onEnded { _ in isDown = false })
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(PanelStyle.label)
        }
        .frame(width: 76)
    }
}

/// SPEED の選択(6段階)。
struct SpeedSelector: View {
    @Binding var selection: SpeedSetting

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(SpeedSetting.allCases, id: \.self) { s in
                    VStack(spacing: 3) {
                        LEDView(level: selection == s ? 1 : 0, color: Color(red: 1, green: 0.7, blue: 0.1), size: 9)
                        Text(s.label)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(PanelStyle.label)
                    }
                    .frame(width: 42)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = s }
                }
            }
            Text("SPEED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(PanelStyle.label)
        }
    }
}

enum PanelStyle {
    static let label = Color(white: 0.82)
    static let body = LinearGradient(
        colors: [Color(red: 0.16, green: 0.19, blue: 0.27), Color(red: 0.10, green: 0.12, blue: 0.18)],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - パネル全体

struct FrontPanelView: View {
    @ObservedObject var model: PanelModel

    private let flagLabels = ["C", "Z", "I", "D", "B", "-", "V", "N"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .bottom, spacing: 22) {
                        LEDRow(title: "ADDRESS BUS", levels: model.address,
                               bitLabels: (0..<16).map { "A\($0)" })
                        LEDRow(title: "DATA BUS", levels: model.data,
                               bitLabels: (0..<8).map { "D\($0)" })
                    }
                    HStack(alignment: .bottom, spacing: 22) {
                        LEDRow(title: "PC", levels: model.pc)
                        LEDRow(title: "SP", levels: model.sp)
                    }
                    HStack(alignment: .bottom, spacing: 22) {
                        LEDRow(title: "A", levels: model.a)
                        LEDRow(title: "X", levels: model.x)
                        LEDRow(title: "Y", levels: model.y)
                    }
                    LEDRow(title: "STATUS P", levels: model.status, bitLabels: flagLabels,
                           color: Color(red: 1.0, green: 0.55, blue: 0.1))
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("CPU")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PanelStyle.label)
                    HStack(spacing: 2) {
                        SingleLED(title: "SYNC", level: model.syncLED)
                        SingleLED(title: "READ", level: model.readLED)
                        SingleLED(title: "WRITE", level: model.writeLED)
                    }
                    HStack(spacing: 2) {
                        SingleLED(title: "RUN", level: model.runLED, color: .green)
                        SingleLED(title: "HALT", level: model.haltLED)
                        SingleLED(title: "IRQ", level: model.irqLED)
                        SingleLED(title: "NMI", level: model.nmiLED)
                    }
                    HStack(spacing: 2) {
                        SingleLED(title: "TX", level: model.txLED, color: .green)
                        SingleLED(title: "RX", level: model.rxLED, color: .green)
                    }
                    Text("CYCLES \(model.cycleCount)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PanelStyle.label.opacity(0.8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INSTRUCTION AT PC")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PanelStyle.label)
                        Text(model.instructionLine.isEmpty ? " " : model.instructionLine)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color(red: 0.55, green: 1.0, blue: 0.6))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .padding(.top, 6)
                }
            }

            Divider().overlay(Color.white.opacity(0.15))

            HStack(alignment: .bottom, spacing: 18) {
                ToggleSwitch(
                    title: "POWER", upLabel: "ON", downLabel: "OFF",
                    isOn: Binding(get: { model.isPowerOn }, set: { model.setPower($0) }))
                // CPU の種類。電源が OFF のときだけ切り替えられる
                ToggleSwitch(
                    title: "CPU \(model.cpuModel.displayName)", upLabel: "65C02", downLabel: "6502",
                    isOn: Binding(
                        get: { model.cpuModel == .cmos65C02 },
                        set: { model.setCPUModel($0 ? .cmos65C02 : .nmos6502) }))
                    .opacity(model.isPowerOn ? 0.45 : 1)
                    .allowsHitTesting(!model.isPowerOn)
                MomentarySwitch(title: "RESET") { model.pressReset() }
                MomentarySwitch(title: "NMI") { model.pressNMI() }
                ToggleSwitch(
                    title: "RUN/STOP", upLabel: "RUN", downLabel: "STOP",
                    isOn: Binding(get: { model.isRunSwitchOn }, set: { model.setRun($0) }))
                MomentarySwitch(title: "STEP") { model.pressStep() }
                ToggleSwitch(
                    title: "STEP MODE", upLabel: "CYCLE", downLabel: "INSTR",
                    isOn: $model.stepsByCycle)
                Spacer(minLength: 10)
                SpeedSelector(selection: Binding(get: { model.speed }, set: { model.setSpeed($0) }))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PanelStyle.body)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }
}

// MARK: - 端末

struct TerminalView: View {
    @ObservedObject var terminal: TerminalModel
    let onKey: (UInt8) -> Void
    /// Edit → Paste(⌘V)
    let onPaste: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(terminal.text + "\u{2588}")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(red: 0.55, green: 1.0, blue: 0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .id("bottom")
            }
            .onChange(of: terminal.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .padding(10)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onTapGesture { focused = true }
        .onPasteCommand(of: [.plainText]) { _ in onPaste() }
        .onKeyPress(phases: [.down, .repeat]) { press in
            if press.key == .return { onKey(0x0D); return .handled }
            if press.key == .delete { onKey(0x08); return .handled }
            if press.key == .escape { onKey(0x1B); return .handled }
            if press.modifiers.contains(.control), let c = press.characters.unicodeScalars.first {
                // Ctrl+文字は制御コードで届く場合と、文字そのままの場合がある
                if c.value < 0x20 { onKey(UInt8(c.value)); return .handled }
                if c.value >= 0x61, c.value <= 0x7A { onKey(UInt8(c.value - 0x60)); return .handled }
            }
            guard !press.modifiers.contains(.command) else { return .ignored }
            var handled = false
            for scalar in press.characters.unicodeScalars where scalar.value >= 0x20 && scalar.value < 0x7F {
                onKey(UInt8(scalar.value))
                handled = true
            }
            return handled ? .handled : .ignored
        }
    }
}
