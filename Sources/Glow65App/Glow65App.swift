import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `swift run` でもウインドウが前面に出るようにする
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct Glow65App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = PanelModel()

    var body: some Scene {
        WindowGroup("Glow65") {
            ContentView(model: model)
                .frame(minWidth: 940, minHeight: 760)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @ObservedObject var model: PanelModel
    /// 動作確認用の起動オプション(--power-on / --no-splash)があるときは出さない。
    @State private var showsSplash = !CommandLine.arguments.contains("--no-splash")
        && !CommandLine.arguments.contains("--power-on")
        && !CommandLine.arguments.contains("--power-on-after")

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                FrontPanelView(model: model)
                if let error = model.romError {
                    Text(error).foregroundStyle(.orange).font(.callout)
                }
                TerminalView(terminal: model.terminal) { model.typed($0) }
            }
            .padding(14)
            .background(Color(white: 0.07))
            .overlay(alignment: .topTrailing) {
                Button {
                    showsSplash = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(white: 0.6))
                }
                .buttonStyle(.plain)
                .padding(22)
                .help("About Glow65 / クレジットを表示")
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
