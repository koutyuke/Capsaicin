import AppKit
import SwiftUI

@main
struct CapsaicinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            Button {
                delegate.quitByUser()
            } label: {
                Text("終了", tableName: "MenuBar")
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: "flame")
                .accessibilityLabel(Text("Capsaicin", tableName: "MenuBar"))
        }
    }
}
