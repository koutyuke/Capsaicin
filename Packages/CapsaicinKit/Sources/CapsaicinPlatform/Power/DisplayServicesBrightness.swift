import CapsaicinCore
import CoreGraphics
import Darwin

/// 非公開の DisplayServices を実行時に引く。生成時は関数の読み込みだけを行い、輝度を変えない。
@MainActor
public final class DisplayServicesBrightness: BuiltInDisplayBrightnessControlling {
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    private typealias CanChangeBrightness = @convention(c) (UInt32) -> Bool

    private let library: UnsafeMutableRawPointer?
    private let get: GetBrightness?
    private let set: SetBrightness?
    private let canChange: CanChangeBrightness?

    public init() {
        library = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
        get = library.flatMap { dlsym($0, "DisplayServicesGetBrightness") }
            .map { unsafeBitCast($0, to: GetBrightness.self) }
        set = library.flatMap { dlsym($0, "DisplayServicesSetBrightness") }
            .map { unsafeBitCast($0, to: SetBrightness.self) }
        canChange = library.flatMap { dlsym($0, "DisplayServicesCanChangeBrightness") }
            .map { unsafeBitCast($0, to: CanChangeBrightness.self) }
    }

    public var isKnownUnavailable: Bool {
        guard get != nil, set != nil, let canChange else { return true }
        guard let display = try? builtInDisplay() else { return false }
        return !canChange(display)
    }

    public func readBrightness() throws -> Float? {
        guard let display = try builtInDisplay() else { return nil }
        guard let get else { throw PowerPlatformError.unavailable("DisplayServicesGetBrightness") }
        var value: Float = 0
        let status = get(display, &value)
        guard status == 0 else {
            throw PowerPlatformError.ioKit(operation: "DisplayServicesGetBrightness", code: status)
        }
        return value
    }

    public func setBrightness(_ value: Float) throws {
        guard let display = try builtInDisplay() else {
            throw PowerPlatformError.unavailable("内蔵ディスプレイ")
        }
        guard let set else { throw PowerPlatformError.unavailable("DisplayServicesSetBrightness") }
        let status = set(display, value)
        guard status == 0 else {
            throw PowerPlatformError.ioKit(operation: "DisplayServicesSetBrightness", code: status)
        }
    }

    private func builtInDisplay() throws -> CGDirectDisplayID? {
        var count: UInt32 = 0
        var status = CGGetOnlineDisplayList(0, nil, &count)
        guard status == .success else {
            throw PowerPlatformError.unavailable("CGGetOnlineDisplayList: \(status.rawValue)")
        }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        status = CGGetOnlineDisplayList(count, &displays, &count)
        guard status == .success else {
            throw PowerPlatformError.unavailable("CGGetOnlineDisplayList: \(status.rawValue)")
        }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    isolated deinit {
        if let library {
            dlclose(library)
        }
    }
}
