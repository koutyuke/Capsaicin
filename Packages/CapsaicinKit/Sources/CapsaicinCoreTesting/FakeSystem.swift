import CapsaicinCore
import Foundation

/// すべてのポートを1つで受け持つ偽物。操作を順に記録し、指定した操作を失敗させる。
@MainActor
public final class FakeSystem {
    /// ポートへの操作。`failing` に入れると、その操作が失敗する。
    public enum Operation: Hashable, Sendable {
        case createAssertion(AssertionKind)
        case releaseAssertion(AssertionKind)
        case readSleepDisabled
        case helperOn
        case helperOff
        case setLEDLit(Bool)
        case readBrightness
        case setBrightness(Float)
        case saveBrightnessRecord(Float)
        case removeBrightnessRecord
    }

    public struct Failure: Error {}

    // MARK: 時刻

    public var now: Date
    public var calendar: Calendar

    // MARK: 機器の状態

    public var powerState = PowerState(batteryLevel: 80, isOnACPower: false)
    public var isHelperInstalled = true
    public var isLEDAvailable = true
    public var sleepDisabled = false
    public var brightness: Float? = 0.5
    public var isKnownUnavailable = false
    public private(set) var heldAssertions: Set<AssertionKind> = []
    /// 冪等の約束により何もしなかったアサーションの操作（作ってある種類の作成、作っていない種類の解放）の数。
    public private(set) var redundantAssertionCalls = 0
    public private(set) var isLEDLit = false

    // MARK: 記録

    public var brightnessRecord: BrightnessRecord?

    public var failing: Set<Operation> = []
    public private(set) var operations: [Operation] = []

    public init(
        now: Date = Date(timeIntervalSince1970: 1_800_000_000),
        calendar: Calendar = Calendar(identifier: .gregorian),
    ) {
        self.now = now
        self.calendar = calendar
    }

    public var ports: BlockingController.Ports {
        BlockingController.Ports(
            assertions: self, helper: self, led: self, brightness: self,
            power: self, brightnessRecords: self, time: self,
        )
    }

    public func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }

    /// これまでの操作の履歴を消す。偽物の状態は変えない。
    public func clearHistory() {
        operations = []
    }

    private func perform(_ operation: Operation) throws {
        operations.append(operation)
        if failing.contains(operation) {
            throw Failure()
        }
    }
}

extension FakeSystem: PowerAssertionControlling {
    public func createAssertion(_ kind: AssertionKind) throws {
        try perform(.createAssertion(kind))
        if !heldAssertions.insert(kind).inserted {
            redundantAssertionCalls += 1
        }
    }

    public func releaseAssertion(_ kind: AssertionKind) throws {
        try perform(.releaseAssertion(kind))
        if heldAssertions.remove(kind) == nil {
            redundantAssertionCalls += 1
        }
    }
}

extension FakeSystem: HelperSleepControlling {
    public func readSleepDisabled() throws -> Bool {
        try perform(.readSleepDisabled)
        return sleepDisabled
    }

    public func turnOn() throws {
        try perform(.helperOn)
        sleepDisabled = true
    }

    public func turnOff() throws {
        try perform(.helperOff)
        sleepDisabled = false
    }
}

extension FakeSystem: CapsLockLEDControlling {
    public var isAvailable: Bool {
        isLEDAvailable
    }

    public func setLit(_ lit: Bool) throws {
        try perform(.setLEDLit(lit))
        isLEDLit = lit
    }
}

extension FakeSystem: PowerStateProviding, TimeProviding {}

extension FakeSystem: BuiltInDisplayBrightnessControlling {
    public func readBrightness() throws -> Float? {
        try perform(.readBrightness)
        return brightness
    }

    public func setBrightness(_ value: Float) throws {
        try perform(.setBrightness(value))
        brightness = value
    }
}

extension FakeSystem: BrightnessRecordStoring {
    public func load() -> BrightnessRecord? {
        brightnessRecord
    }

    public func save(_ brightness: Float) -> Bool {
        guard (try? perform(.saveBrightnessRecord(brightness))) != nil else { return false }
        brightnessRecord = BrightnessRecord(savedBrightness: brightness)
        return true
    }

    public func remove() -> Bool {
        guard (try? perform(.removeBrightnessRecord)) != nil else { return false }
        brightnessRecord = nil
        return true
    }
}
