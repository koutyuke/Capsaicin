import AppKit
import CapsaicinCore
import SwiftUI

extension Image {
    init(symbol name: String, bundle: Bundle) {
        self = name.hasPrefix("custom.") ? Image(name, bundle: bundle) : Image(systemName: name)
    }
}

struct SettingsInfo: View {
    let title: String
    let help: String
    @State private var isOpen = false
    var body: some View {
        Button { isOpen.toggle() } label: {
            Image(systemName: "info.circle").imageScale(.small).foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(String(format: SettingsSection.general.text("help.a11y"), title))
        .popover(isPresented: $isOpen) {
            Text(help).font(.callout).padding(16).frame(idealWidth: 280).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    var help = ""
    var child = false
    var enabled = true
    var warning = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack {
            HStack {
                if warning {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        .accessibilityLabel(SettingsSection.sleep.text("helperNotReady.a11y"))
                }
                Text(title).foregroundStyle(enabled ? .primary : .secondary)
                    .disabled(!enabled)
                if !help.isEmpty {
                    SettingsInfo(title: title, help: help)
                }
            }
            .padding(.leading, child ? 20 : 0)
            Spacer()
            content().disabled(!enabled)
                .accessibilityLabel(title).accessibilityHint(help)
        }
    }
}

struct SettingsDurationField: View {
    @Binding var value: TimerDuration
    var body: some View {
        HStack(spacing: 8) {
            number("hours", get: { value.minutes / 60 }, set: { setMinutes($0 * 60 + value.minutes % 60) })
            number("minutes", get: { value.minutes % 60 }, set: { setMinutes(value.minutes / 60 * 60 + $0) })
            Stepper(SettingsSection.release.text("timer.duration.label"), onIncrement: {
                setMinutes(min(1440, value.minutes + 5))
            }, onDecrement: { setMinutes(max(1, value.minutes - 5)) }).labelsHidden()
        }.monospacedDigit()
    }

    private func number(_ unit: String, get: @escaping @MainActor @Sendable () -> Int,
                        set: @escaping @MainActor @Sendable (Int) -> Void) -> some View
    {
        HStack(spacing: 4) {
            TextField(SettingsSection.release.text(unit), value: Binding(get: get, set: set), format: .number)
                .labelsHidden().frame(width: 40).multilineTextAlignment(.trailing)
            Text(SettingsSection.release.text(unit)).foregroundStyle(.secondary)
        }
    }

    private func setMinutes(_ minutes: Int) {
        if let duration = TimerDuration(minutes: minutes) {
            value = duration
        }
    }
}

struct SettingsCopyButton: View {
    let path: String
    @State private var copied = false
    @State private var reset: Task<Void, Never>?
    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
            copied = true
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
                .announcement: SettingsSection.controls.text("cli.path.copied.a11y"),
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ])
            reset?.cancel()
            reset = Task {
                do { try await Task.sleep(for: .milliseconds(1500)); copied = false } catch { return }
            }
        } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
            .buttonStyle(.borderless)
            .help(SettingsSection.controls.text("cli.path.copy.a11y"))
            .accessibilityLabel(SettingsSection.controls.text("cli.path.copy.a11y"))
            .onDisappear { reset?.cancel() }
    }
}
