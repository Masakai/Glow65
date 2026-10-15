import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PanelModel
    /// 動作確認用の起動オプション(--power-on / --no-splash)があるときは出さない。
    @State private var showsSplash = !CommandLine.arguments.contains("--no-splash")
        && !CommandLine.arguments.contains("--power-on")
        && !CommandLine.arguments.contains("--power-on-after")
#if os(iOS)
    @State private var showsLoadSheet = false
    @State private var sendingTextFile = false
    /// パネルは、この幅で組んで、画面が狭いときだけ縮めて表示する。
    private let designWidth: CGFloat = 1040
#endif

    var body: some View {
#if os(iOS)
        GeometryReader { geo in
            let scale = min(1, geo.size.width / designWidth)
            content
                .frame(width: geo.size.width / scale, height: geo.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(Color(white: 0.07).ignoresSafeArea())
        .sheet(isPresented: $showsLoadSheet) { LoadProgramSheet(model: model, isPresented: $showsLoadSheet) }
        .fileImporter(isPresented: $sendingTextFile, allowedContentTypes: [.text, .plainText]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            model.sendTextFile(url)
        }
#else
        content
#endif
    }

    private var content: some View {
        ZStack {
            VStack(spacing: 12) {
                FrontPanelView(model: model)
                if let error = model.romError {
                    Text(error).foregroundStyle(.orange).font(.callout)
                }
                if let message = model.statusMessage {
                    Text(message).foregroundStyle(Color(white: 0.7)).font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                TerminalView(terminal: model.terminal,
                             onKey: { model.typed($0) },
                             onPaste: { model.pasteFromClipboard() })
            }
            .padding(14)
            .background(Color(white: 0.07))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 14) {
#if os(iOS)
                    Menu {
                        Button("Load Program…", systemImage: "square.and.arrow.down") { showsLoadSheet = true }
                        Button("Send Text File…", systemImage: "doc.text") { sendingTextFile = true }
                        Button("Paste", systemImage: "doc.on.clipboard") { model.pasteFromClipboard() }
                        let examples = ExampleText.all
                        if !examples.isEmpty {
                            Menu("Send Example", systemImage: "gamecontroller") {
                                ForEach(examples) { example in
                                    Button(example.name) { model.sendTextFile(example.url) }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17))
                            .foregroundStyle(Color(white: 0.6))
                    }
#endif
                    Button {
                        showsSplash = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(white: 0.6))
                    }
                    .buttonStyle(.plain)
                    .help("About Glow65 / show credits")
                }
                .padding(22)
            }

            if showsSplash {
                SplashView { withAnimation(.easeOut(duration: 0.4)) { showsSplash = false } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
    }
}
