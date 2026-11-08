import CapsaicinCore
import Foundation
import IOKit
import IOKit.ps

/// CF の所有期間の内側で値を取り出し、変換は OS に依存せず検証する。
struct PowerSnapshot {
    var sources: [[String: Any]]
    var providingSource: String?

    var internalBattery: [String: Any]? {
        sources.first { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }
    }

    var powerState: PowerState {
        guard let battery = internalBattery else {
            return PowerState(batteryLevel: nil, isOnACPower: providingSource == kIOPSACPowerValue)
        }
        return PowerState(
            batteryLevel: Self.percentage(battery),
            isOnACPower: battery[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
        )
    }

    private static func percentage(_ battery: [String: Any]) -> Int? {
        if let present = battery[kIOPSIsPresentKey] {
            guard let number = present as? NSNumber,
                  CFGetTypeID(number) == CFBooleanGetTypeID(), number.boolValue
            else { return nil }
        }
        guard let current = integer(battery[kIOPSCurrentCapacityKey]), current >= 0,
              let maximum = integer(battery[kIOPSMaxCapacityKey]), maximum > 0
        else { return nil }
        guard current < maximum else { return 100 }
        // 倍幅の積でオーバーフローと浮動小数誤差を避け、正確な比率の小数部を切り捨てる。
        let scaled = UInt64(current).multipliedFullWidth(by: 100)
        return Int(UInt64(maximum).dividingFullWidth(scaled).quotient)
    }

    private static func integer(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFNumberGetTypeID() else { return nil }
        let cfNumber = unsafeBitCast(number, to: CFNumber.self)
        guard !CFNumberIsFloatType(cfNumber) else { return nil }
        var integer: Int64 = 0
        guard CFNumberGetValue(cfNumber, .sInt64Type, &integer),
              number.compare(NSNumber(value: integer)) == .orderedSame
        else { return nil }
        return integer
    }

    static func read() -> Self {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return Self(sources: [], providingSource: nil)
        }
        let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
        let sources = list.compactMap { source in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }
        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        return Self(sources: sources, providingSource: providing)
    }
}

@MainActor
public enum PowerMachineCapabilities {
    public static func detect() -> MachineCapabilities {
        detect(clamshellProperty: readClamshellProperty(), snapshot: .read())
    }

    static func detect(clamshellProperty: Any?, snapshot: PowerSnapshot) -> MachineCapabilities {
        MachineCapabilities(
            hasLid: clamshellProperty != nil,
            hasInternalBattery: snapshot.internalBattery != nil,
        )
    }
}

func readClamshellProperty() -> Any? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    return IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue()
}

func clamshellIsClosed(_ property: Any?) -> Bool? {
    guard let number = property as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
    return number.boolValue
}
