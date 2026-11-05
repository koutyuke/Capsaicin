import AppKit
import SwiftUI

@main
struct CapsaicinApp: App {
    var body: some Scene {
        MenuBarExtra {
            Button {
                NSApplication.shared.terminate(nil)
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
