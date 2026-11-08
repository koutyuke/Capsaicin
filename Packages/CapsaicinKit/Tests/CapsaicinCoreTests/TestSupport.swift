@testable import CapsaicinCore
import CapsaicinCoreTesting
import Foundation

extension Settings {
    /// 受け入れ例の共通の前提: 既定値で、解除の条件はすべてオフ。
    static func premise(_ change: (inout Settings) -> Void = { _ in }) -> Settings {
        var settings = Settings()
        settings.blocksDisplaySleep = false
        settings.batteryConditionEnabled = false
        change(&settings)
        return settings
    }
}

extension MachineCapabilities {
    static let laptop = MachineCapabilities(hasLid: true, hasInternalBattery: true)
    static let desktop = MachineCapabilities(hasLid: false, hasInternalBattery: false)
}

/// コントローラーの通知を記録する。
@MainActor
final class EventRecorder {
    private(set) var events: [BlockingEvent] = []

    init(_ controller: BlockingController) {
        controller.onEvent = { [unowned self] in events.append($0) }
    }

    /// 警告の変化を除いた通知。
    var stateEvents: [BlockingEvent] {
        events.filter { $0 != .warningsChanged }
    }
}

@MainActor
func makeController(
    _ system: FakeSystem,
    settings: Settings = .premise(),
    capabilities: MachineCapabilities = .laptop,
    launch: Bool = true,
) -> BlockingController {
    let controller = BlockingController(settings: settings, capabilities: capabilities, ports: system.ports)
    if launch {
        controller.launch()
    }
    return controller
}

func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

extension Calendar {
    /// この暦とタイムゾーンでの壁時計の時刻。
    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
    TimeOfDay(hour: hour, minute: minute)!
}

func minutes(_ value: Int) -> TimerDuration {
    TimerDuration(minutes: value)!
}
