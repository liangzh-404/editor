import SwiftUI

enum AppEnvironment {
    @MainActor
    static func makeRootView() -> some View {
        EditorShellView()
    }
}

