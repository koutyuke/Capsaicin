import CapsaicinCore
import SwiftUI

struct DurationInput: Equatable {
    var hours: String
    var minutes: String

    init(_ value: TimerDuration) {
        hours = String(value.minutes / 60)
        minutes = String(value.minutes % 60)
    }

    var value: TimerDuration? {
        guard let hours = Int(hours), (0 ... 24).contains(hours),
              let minutes = Int(minutes), (0 ... 59).contains(minutes) else { return nil }
        return TimerDuration(minutes: hours * 60 + minutes)
    }

    mutating func step(_ delta: Int) {
        guard let value else { return }
        self = DurationInput(TimerDuration(minutes: min(1440, max(1, value.minutes + delta)))!)
    }
}

struct DurationField: View {
    @Binding var input: DurationInput

    var body: some View {
        HStack(spacing: 8) {
            number("hours", text: $input.hours, step: 60)
            number("minutes", text: $input.minutes, step: 5)
        }.monospacedDigit()
    }

    private func number(_ unit: String, text: Binding<String>, step: Int) -> some View {
        HStack(spacing: 4) {
            TextField(SettingsSection.sleep.text(unit), text: text)
                .labelsHidden().frame(width: 40).multilineTextAlignment(.trailing)
                .onKeyPress(.upArrow) { input.step(step); return .handled }
                .onKeyPress(.downArrow) { input.step(-step); return .handled }
            Text(SettingsSection.sleep.text(unit)).foregroundStyle(.secondary)
            Stepper(SettingsSection.sleep.text(unit), onIncrement: {
                input.step(step)
            }, onDecrement: { input.step(-step) })
                .labelsHidden().disabled(input.value == nil)
        }
    }
}
