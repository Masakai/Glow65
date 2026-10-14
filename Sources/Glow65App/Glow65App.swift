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
                .frame(minWidth: 1040, minHeight: 760)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Load Program…") { model.presentLoadPanel() }
                    .keyboardShortcut("o")
                Button("Send Text File…") { model.presentSendTextPanel() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
