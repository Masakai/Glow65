import SwiftUI

/// iPad 版のエントリーポイント。画面は macOS 版(`Sources/Glow65App`)と同じ部品を使う。
@main
struct Glow65iPadApp: App {
    @StateObject private var model = PanelModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
