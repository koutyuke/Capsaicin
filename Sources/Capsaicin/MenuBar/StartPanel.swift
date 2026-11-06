import AppKit
import CapsaicinCore
import SwiftUI

struct StartPanelInput {
    enum Mode { case duration, time }
    var mode: Mode
    var hours: String
    var minutes: String
    var date: Date

    init(mode: Mode, settings: CapsaicinCore.Settings, now: Date, calendar: Calendar) {
        self.mode = mode
        let duration = (settings.timerEnabled ? settings : CapsaicinCore.Settings()).timerDuration.minutes
        hours = String(duration / 60)
        minutes = String(duration % 60)
        let time = (settings.specifiedTimeEnabled ? settings : CapsaicinCore.Settings()).specifiedTime
        date = SpecifiedTimeRule.releaseDate(for: time, after: now, calendar: calendar)
    }

    func startOverride(calendar: Calendar) -> StartTimeOverride? {
        if mode == .time {
            return TimeOfDay(
                hour: calendar.component(.hour, from: date),
                minute: calendar.component(.minute, from: date),
            )
            .map { .specifiedTime($0) }
        }
        guard let hours = Int(hours), (0 ... 24).contains(hours),
              let minutes = Int(minutes), (0 ... 59).contains(minutes),
              let duration = TimerDuration(minutes: hours * 60 + minutes) else { return nil }
        return .timer(duration)
    }

    func isNextDay(now: Date, calendar: Calendar) -> Bool {
        guard case let .specifiedTime(time) = startOverride(calendar: calendar) else { return false }
        return !calendar.isDate(
            SpecifiedTimeRule.releaseDate(for: time, after: now, calendar: calendar),
            inSameDayAs: now,
        )
    }

    mutating func stepMinutes(_ delta: Int) {
        let current: Int = if case let .timer(duration) = startOverride(calendar: .current) {
            duration.minutes
        } else {
            0
        }
        let value = min(1440, max(1, current + delta))
        hours = String(value / 60)
        minutes = String(value % 60)
    }
}

@MainActor
enum StartPanel {
    static func make(mode: StartPanelInput.Mode, model: AppModel) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 160),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = MenuContent.text(mode == .duration ? "panel.duration.title" : "panel.time.title")
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: StartPanelView(
            input: StartPanelInput(mode: mode, settings: model.settings, now: Date(), calendar: .current),
            cancel: { [weak panel] in panel?.close() },
            start: { [weak panel] value in panel?.close(); model.requestStart(from: .menu, override: value) },
        ))
        let frame = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?.visibleFrame
        if let frame {
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.midY - panel.frame.height / 2,
            ))
        }
        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
        return panel
    }
}

private struct StartPanelView: View {
    @State var input: StartPanelInput
    var cancel: () -> Void
    var start: (StartTimeOverride) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if input.mode == .duration {
                HStack(spacing: 8) {
                    TextField(text: $input.hours) { Text("panel.duration.hours.label", tableName: "MenuBar") }
                    Text("panel.duration.hours.label", tableName: "MenuBar")
                    TextField(text: $input.minutes) { Text("panel.duration.minutes.label", tableName: "MenuBar") }
                    Text("panel.duration.minutes.label", tableName: "MenuBar")
                    Stepper {
                        Text("panel.duration.title", tableName: "MenuBar")
                    } onIncrement: { input.stepMinutes(5) } onDecrement: { input.stepMinutes(-5) }
                        .labelsHidden()
                }
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
            } else {
                DatePicker(selection: $input.date, displayedComponents: .hourAndMinute) {
                    Text("panel.time.label", tableName: "MenuBar")
                }
                .datePickerStyle(.stepperField)
                .monospacedDigit()
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text("panel.time.nextDay", tableName: "MenuBar")
                        .foregroundStyle(.secondary)
                        .opacity(input.isNextDay(now: context.date, calendar: .current) ? 1 : 0)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                Button(action: cancel) { Text("panel.cancel", tableName: "MenuBar") }.keyboardShortcut(.cancelAction)
                Button {
                    if let value = input.startOverride(calendar: .current) {
                        start(value)
                    }
                } label: { Text("panel.start", tableName: "MenuBar") }
                    .keyboardShortcut(.defaultAction)
                    .disabled(input.startOverride(calendar: .current) == nil)
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(width: 300)
    }
}
