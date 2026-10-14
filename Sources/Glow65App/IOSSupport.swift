#if os(iOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 画面のキーボードと外付けキーボードの入力を受け取り、ASCII の 1 バイトにして渡す見えない部品。
/// 端末の領域をタップすると、キーボードが出る。
struct KeyboardCatcher: UIViewRepresentable {
    let onKey: (UInt8) -> Void
    /// 値が変わるたびに、キーボードの入力を受け取る状態にする。
    let focusRequest: Int

    func makeUIView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onKey = onKey
        return view
    }

    func updateUIView(_ view: CatcherView, context: Context) {
        view.onKey = onKey
        if context.coordinator.lastRequest != focusRequest {
            context.coordinator.lastRequest = focusRequest
            DispatchQueue.main.async { _ = view.becomeFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastRequest = -1
    }

    final class CatcherView: UIView, UIKeyInput {
        var onKey: (UInt8) -> Void = { _ in }

        override var canBecomeFirstResponder: Bool { true }

        // 6502 のモニタと BASIC は ASCII だけを扱うので、自動補正の類は止める。
        var autocorrectionType: UITextAutocorrectionType = .no
        var autocapitalizationType: UITextAutocapitalizationType = .none
        var spellCheckingType: UITextSpellCheckingType = .no
        var smartQuotesType: UITextSmartQuotesType = .no
        var smartDashesType: UITextSmartDashesType = .no
        var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
        var keyboardType: UIKeyboardType = .asciiCapable

        var hasText: Bool { true }

        func insertText(_ text: String) {
            for scalar in text.unicodeScalars {
                if scalar == "\n" || scalar == "\r" {
                    onKey(0x0D)
                } else if scalar.value >= 0x20 && scalar.value < 0x7F {
                    onKey(UInt8(scalar.value))
                }
            }
        }

        func deleteBackward() { onKey(0x08) }

        // Esc と Ctrl+文字は、文字入力としては届かないので、キーの押下から拾う。
        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var unhandled = Set<UIPress>()
            for press in presses {
                guard let key = press.key else { unhandled.insert(press); continue }
                if key.keyCode == .keyboardEscape {
                    onKey(0x1B)
                } else if key.modifierFlags.contains(.control),
                          let c = key.charactersIgnoringModifiers.lowercased().unicodeScalars.first,
                          c.value >= 0x61, c.value <= 0x7A {
                    onKey(UInt8(c.value - 0x60))
                } else {
                    unhandled.insert(press)
                }
            }
            if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
        }
    }
}

/// 「Load Program…」のシート。読み込み先のアドレスを入力してから、ファイルを選ぶ。
struct LoadProgramSheet: View {
    @ObservedObject var model: PanelModel
    @Binding var isPresented: Bool
    @State private var address = "0300"
    @State private var choosing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("$")
                        TextField("0300", text: $address)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Load at (hexadecimal)")
                } footer: {
                    Text("Choose a raw binary, for example one built with Tools/assemble.sh. RAM is $0000-$7FFF.")
                }
                Section {
                    Button("Choose file…") { choosing = true }
                }
                let samples = SampleProgram.all
                if !samples.isEmpty {
                    Section("Samples (included in the app)") {
                        ForEach(samples) { sample in
                            Button(sample.name) {
                                model.loadProgram(at: sample.url, addressText: address)
                                isPresented = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Load Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
            }
            .fileImporter(isPresented: $choosing, allowedContentTypes: [.data]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                model.loadProgram(at: url, addressText: address)
                isPresented = false
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// アプリに同梱したサンプル(チュートリアルの `.bin`)。
struct SampleProgram: Identifiable {
    let url: URL
    var id: String { url.lastPathComponent }
    var name: String { url.lastPathComponent }

    static var all: [SampleProgram] { BundledFile.list(directory: "tutorial", suffix: ".bin").map(SampleProgram.init) }
}

/// アプリに同梱したテキストの例(`examples/*.gam`、GAME65G のプログラム)。端末へ送る。
struct ExampleText: Identifiable {
    let url: URL
    var id: String { url.lastPathComponent }
    var name: String { url.lastPathComponent }

    static var all: [ExampleText] { BundledFile.list(directory: "examples", suffix: ".gam").map(ExampleText.init) }
}

enum BundledFile {
    static func list(directory: String, suffix: String) -> [URL] {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent(directory),
              let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.filter { $0.hasSuffix(suffix) }.sorted().map { dir.appendingPathComponent($0) }
    }
}
#endif
