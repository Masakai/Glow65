import SwiftUI

/// 起動時のバナー。LED が走り、タイトルとクレジットが順に現れる。
///
/// クレジットは事実どおりに書く。このシステムは全体が独自実装ではなく、
/// Microsoft BASIC(MIT License)を含む。
struct SplashView: View {
    let onFinish: () -> Void

    @State private var startDate = Date()
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 経過秒がこの値以上になると自動で閉じる。
    private let autoCloseSeconds = 14.0

    private struct Credit: Identifiable {
        let id: Int
        let label: String
        let text: String
        let appearsAt: Double
    }

    private var credits: [Credit] { [
        Credit(id: 0, label: loc("ORIGINAL"),
               text: loc("6502 CPU core · board · monitor ROM · front panel · this app"),
               appearsAt: 2.4),
        Credit(id: 1, label: loc("INCLUDES"),
               text: loc("Microsoft BASIC for 6502 v1.1  © Microsoft Corporation  (MIT License)"),
               appearsAt: 3.2),
        Credit(id: 2, label: loc("BUILT WITH"),
               text: "cc65 (zlib License) · Swift · SwiftUI",
               appearsAt: 4.0),
        Credit(id: 3, label: loc("VERIFIED BY"),
               text: loc("Klaus Dormann's 6502 functional test (GPLv3, not included)"),
               appearsAt: 4.8),
    ] }

    var body: some View {
        TimelineView(.animation) { context in
            let t = reduceMotion ? 100 : context.date.timeIntervalSince(startDate)
            ZStack {
                Color(white: 0.04)
                VStack(spacing: 26) {
                    ledRow(t: t)
                    title(t: t)
                    subtitle(t: t)
                    creditList(t: t)
                    prompt(t: t)
                }
                .padding(40)
            }
            .onChange(of: t >= autoCloseSeconds) { _, expired in
                if expired { onFinish() }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear {
            startDate = Date()
            focused = true
        }
        .onKeyPress { _ in
            onFinish()
            return .handled
        }
    }

    // MARK: 部品

    /// 0〜2.0 秒は左右に往復する光、その後は 16 ビットのカウンタ表示(アドレスバスの動き)。
    private func ledRow(t: Double) -> some View {
        let sweepEnd = 2.0
        return HStack(spacing: 10) {
            ForEach(0..<16, id: \.self) { i in
                LEDView(level: ledLevel(index: i, t: t, sweepEnd: sweepEnd), size: 18)
            }
        }
    }

    private func ledLevel(index i: Int, t: Double, sweepEnd: Double) -> Double {
        if t < sweepEnd {
            // 往復する光点と尾
            let phase = (t * 16.0).truncatingRemainder(dividingBy: 30)
            let position = phase <= 15 ? phase : 30 - phase
            return exp(-abs(Double(i) - position) * 0.85)
        }
        // カウンタ: 経過に応じて速くなる(最大 60 カウント/秒)
        let elapsed = t - sweepEnd
        let count = Int(elapsed * elapsed * 30 + elapsed * 8) & 0xFFFF
        let bit = 15 - i  // 左が最上位
        return (count >> bit) & 1 == 1 ? 1 : 0.0
    }

    private func title(t: Double) -> some View {
        let letters = Array("GLOW65")
        return HStack(spacing: 14) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                let local = ease((t - (0.35 + 0.13 * Double(index))) / 0.5)
                Text(String(letter))
                    .font(.system(size: 76, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(color: Color(red: 1.0, green: 0.12, blue: 0.08).opacity(0.9 * (1 - local) + 0.35),
                            radius: 14 * (1 - local) + 6)
                    .opacity(local)
                    .offset(y: (1 - local) * 18)
                    .scaleEffect(1 + (1 - local) * 0.25)
            }
        }
    }

    private func subtitle(t: Double) -> some View {
        Text(loc("6502 SINGLE-BOARD COMPUTER EMULATOR"))
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .tracking(4 + (1 - ease((t - 1.3) / 1.0)) * 10)
            .foregroundStyle(Color(white: 0.75))
            .opacity(ease((t - 1.3) / 0.8))
    }

    private func creditList(t: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(credits) { credit in
                let local = ease((t - credit.appearsAt) / 0.5)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(credit.label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.3))
                        .frame(width: 92, alignment: .trailing)
                    Text(credit.text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color(white: 0.85))
                }
                .opacity(local)
                .offset(x: (1 - local) * 24)
            }
        }
        .padding(.top, 8)
    }

    private func prompt(t: Double) -> some View {
        let blink = 0.5 + 0.5 * sin(t * 4)
        return Text(loc("CLICK OR PRESS ANY KEY"))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(3)
            .foregroundStyle(Color(white: 0.6))
            .opacity(ease((t - 5.6) / 0.6) * (0.4 + 0.6 * blink))
            .padding(.top, 10)
    }

    /// 0...1 に制限した ease-out。
    private func ease(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return 1 - (1 - c) * (1 - c) * (1 - c)
    }
}
