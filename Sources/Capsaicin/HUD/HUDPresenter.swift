import AppKit
import SwiftUI

private final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class HUDPresenter: NSObject {
    private let presentation = HUDPresentation()
    private let isEnabled: () -> Bool
    private var dismissal: Task<Void, Never>?
    private lazy var panel: NSPanel = {
        let panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 452, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: HUDView(presentation: presentation))
        return panel
    }()

    init(isEnabled: @escaping () -> Bool = { true }) {
        self.isEnabled = isEnabled
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hide),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
    }

    deinit { dismissal?.cancel() }

    func show(_ content: HUDContent) {
        if NSWorkspace.shared.isVoiceOverEnabled {
            NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested, userInfo: [
                .announcement: content.announcement, .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ])
        }
        guard isEnabled() else { hide(); return }
        dismissal?.cancel()
        let phase = presentation.phase
        if phase == .hidden {
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen
                .main else { return }
            // ガラスの周囲16 ptを空け、カプセルの下端をvisibleFrameから64 pt上に置く。
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 226, y: screen.visibleFrame.minY + 48))
        }
        presentation.replace(
            content,
            measuredWidth: NSHostingView(rootView: HUDLabel(content: content).fixedSize()).fittingSize.width,
        )
        if phase == .hidden {
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.orderFrontRegardless()
        }
        presentation.phase = phase == .hidden ? .entering : .holding
        dismissal = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(phase.replacementDuration))
                self?.presentation.phase = .holding
                try await Task.sleep(for: .seconds(1.6))
                self?.presentation.phase = .exiting
                try await Task.sleep(for: .seconds(0.30))
                self?.hide()
            } catch {
                // 次の表示が、同じパネルの表示時間を数え直す。
            }
        }
    }

    @objc private func hide() {
        dismissal?.cancel()
        panel.orderOut(nil)
        presentation.phase = .hidden
    }
}
