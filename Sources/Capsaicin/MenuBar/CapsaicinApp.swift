import AppKit
import SwiftUI

@main
struct CapsaicinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(MenuContent.text("menu.settings")) { delegate.runtime?.openSettings() }
                        .keyboardShortcut(",")
                }
                CommandGroup(replacing: .appTermination) {
                    Button(MenuContent.text("menu.quit")) { delegate.quitByUser() }
                        .keyboardShortcut("q")
                }
            }
    }
}
