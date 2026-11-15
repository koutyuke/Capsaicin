import AppKit
import CapsaicinCore
import SwiftUI

struct StartPanelInput {
    enum Mode { case duration, time }
    var mode: Mode
    var duration: DurationInput
    var date: Date
    let isReplacing: Bool

    init(mode: Mode, settings: CapsaicinCore.Settings, session: BlockingSession? = nil,
         now: Date, calendar: Calendar)
    {
        self.mode = mode
        isReplacing = session != nil
        let savedDuration = (settings.timerEnabled ? settings : CapsaicinCore.Settings()).timerDuration
        duration = DurationInput(savedDuration)
        if let limit = session?.timeLimit {
            let remaining = Int(ceil(limit.date.timeIntervalSince(now) / 60))
            duration.hours = String(remaining / 60)
            duration.minutes = String(remaining % 60)
        }
        let time = (settings.specifiedTimeEnabled ? settings : CapsaicinCore.Settings()).specifiedTime
        date = session?.timeLimit?.date ?? SpecifiedTimeRule.releaseDate(for: time, after: now, calendar: calendar)
    }

    var titleKey: String {
        isReplacing ? "panel.changeTime.title" : (mode == .duration ? "panel.duration.title" : "panel.time.title")
    }

    var confirmKey: String {
        isReplacing ? "panel.change" : "panel.start"
    }

    func startOverride(calendar: Calendar) -> StartTimeOverride? {
        if mode == .time {
            return TimeOfDay(
                hour: calendar.component(.hour, from: date),
                minute: calendar.component(.minute, from: date),
            )
            .map { .specifiedTime($0) }
        }
        return duration.value.map { .timer($0) }
    }

    func isNextDay(now: Date, calendar: Calendar) -> Bool {
        guard case let .specifiedTime(time) = startOverride(calendar: calendar) else { return false }
        return !calendar.isDate(
            SpecifiedTimeRule.releaseDate(for: time, after: now, calendar: calendar),
            inSameDayAs: now,
        )
    }

    func releaseDate(now: Date, calendar: Calendar) -> Date? {
        switch startOverride(calendar: calendar) {
        case let .timer(duration): now.addingTimeInterval(Double(duration.minutes * 60))
        case let .specifiedTime(time): SpecifiedTimeRule.releaseDate(for: time, after: now, calendar: calendar)
        case .noTimeLimit, nil: nil
        }
    }
}

@MainActor
enum StartPanel {
    static func make(mode: StartPanelInput.Mode, model: AppModel) -> NSPanel {
        let input = StartPanelInput(mode: mode, settings: model.settings, session: model.status.session,
                                    now: Date(), calendar: .current)
        let panel = makePanel(input: input, start: { model.requestStart(from: .menu, override: $0) })
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

    static func makePanel(input: StartPanelInput, start: @escaping (StartTimeOverride) -> Void) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 160),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = MenuContent.text(input.titleKey)
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: StartPanelView(
            input: input,
            cancel: { [weak panel] in panel?.close() },
            start: { [weak panel] value in panel?.close(); start(value) },
        ))
        return panel
    }
}

struct StartPanelView: View {
    @State var input: StartPanelInput
    var cancel: () -> Void
    var start: (StartTimeOverride) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if input.mode == .duration {
                DurationField(input: $input.duration)
            } else {
                DatePicker(selection: $input.date, displayedComponents: .hourAndMinute) {
                    Text("panel.time.label", tableName: "MenuBar")
                }
                .datePickerStyle(.stepperField)
                .monospacedDigit()
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                if input.mode == .duration {
                    Text(input.releaseDate(now: context.date, calendar: .current).map {
                        String(
                            format: MenuContent.text("panel.duration.until"),
                            DisplayFormat.time($0),
                        )
                    } ?? "")
                        .foregroundStyle(.secondary).monospacedDigit()
                } else {
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
                } label: { Text(MenuContent.text(input.confirmKey)) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(input.startOverride(calendar: .current) == nil)
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(width: 300)
    }
}
