import Foundation

public struct TimerDuration: Hashable, Sendable, Codable {
    public static let allowedMinutes = 1 ... 24 * 60

    public let minutes: Int

    public init?(minutes: Int) {
        guard Self.allowedMinutes.contains(minutes) else { return nil }
        self.minutes = minutes
    }

    public var timeInterval: TimeInterval {
        TimeInterval(minutes * 60)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let minutes = try container.decode(Int.self)
        guard let value = Self(minutes: minutes) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "タイマーの範囲外: \(minutes)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(minutes)
    }
}

public struct TimeOfDay: Hashable, Sendable, Codable {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0 ... 23).contains(hour), (0 ... 59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    private enum CodingKeys: String, CodingKey {
        case hour, minute
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hour = try container.decode(Int.self, forKey: .hour)
        let minute = try container.decode(Int.self, forKey: .minute)
        guard let value = Self(hour: hour, minute: minute) else {
            throw DecodingError.dataCorruptedError(
                forKey: .hour, in: container, debugDescription: "時刻の範囲外: \(hour):\(minute)",
            )
        }
        self = value
    }
}

public struct BatteryThreshold: Hashable, Sendable, Codable {
    public static let allowedPercents = 5 ... 100
    public static let step = 5

    public let percent: Int

    public init?(percent: Int) {
        guard Self.allowedPercents.contains(percent), percent.isMultiple(of: Self.step) else { return nil }
        self.percent = percent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let percent = try container.decode(Int.self)
        guard let value = Self(percent: percent) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "しきい値の範囲外: \(percent)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(percent)
    }
}
