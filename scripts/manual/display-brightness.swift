// オーナー専用。エージェントが実行してよいのは get だけである。
import CoreGraphics
import Darwin
import Foundation
import IOKit

struct Failure: Error, CustomStringConvertible { let description: String }
func check(_ status: Int32, _ operation: String) throws {
    guard status == 0 else { throw Failure(description: "\(operation): status=\(status)") }
}

func properties(_ name: String) throws -> [String: Any] {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(name))
    guard service != 0 else { throw Failure(description: "\(name) がない") }
    defer { IOObjectRelease(service) }
    var result: Unmanaged<CFMutableDictionary>?
    try check(IORegistryEntryCreateCFProperties(service, &result, kCFAllocatorDefault, 0), name)
    return result!.takeRetainedValue() as NSDictionary as! [String: Any]
}

func level(_ text: String) -> Float? {
    guard let value = Double(text), value.isFinite, (0 ... 1).contains(value) else { return nil }
    return Float(value)
}

func amperage(_ number: NSNumber) -> Int32 {
    Int32(truncatingIfNeeded: number.int64Value)
}

assert(level("0") == 0 && level("1") == 1)
assert(["-1", "1.00000001", "2", "nan", "inf", "x"].allSatisfy { level($0) == nil })
assert(amperage(NSNumber(value: UInt64.max - 499)) == -500 && amperage(500) == 500)

@MainActor
final class Probe {
    let display: CGDirectDisplayID
    let library: UnsafeMutableRawPointer
    let get: @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    let set: @convention(c) (UInt32, Float) -> Int32
    let dim: Bool
    var previousClosed: Bool?
    var saved: Float?

    init(dim: Bool) throws {
        var count: UInt32 = 0
        try check(Int32(CGGetOnlineDisplayList(0, nil, &count).rawValue), "CGGetOnlineDisplayList")
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        try check(Int32(CGGetOnlineDisplayList(count, &displays, &count).rawValue), "CGGetOnlineDisplayList")
        guard let display = displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            throw Failure(description: "オンラインの内蔵ディスプレイがない")
        }
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let library = dlopen(path, RTLD_NOW) else {
            throw Failure(description: "DisplayServices を開けない")
        }
        guard let getter = dlsym(library, "DisplayServicesGetBrightness"),
              let setter = dlsym(library, "DisplayServicesSetBrightness")
        else {
            dlclose(library)
            throw Failure(description: "DisplayServices の輝度関数がない")
        }
        self.display = display
        self.library = library
        get = unsafeBitCast(getter, to: (@convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32).self)
        set = unsafeBitCast(setter, to: (@convention(c) (UInt32, Float) -> Int32).self)
        self.dim = dim
    }

    func brightness() throws -> Float {
        var value: Float = 0
        try check(get(display, &value), "DisplayServicesGetBrightness")
        return value
    }

    func write(_ value: Float) throws {
        try check(set(display, value), "DisplayServicesSetBrightness")
    }

    func restore() throws {
        if let saved {
            try write(saved); self.saved = nil
        }
    }

    func snapshot(_ event: String) throws {
        let lid = try properties("IOPMrootDomain")["AppleClamshellState"] as? Bool
        let battery = try properties("AppleSmartBattery")
        let current = (battery["InstantAmperage"] as? NSNumber).map { String(amperage($0)) } ?? "unknown"
        try print([
            Date().ISO8601Format(), "event=\(event)", "pid=\(getpid())",
            "AppleClamshellState=\(lid.map { $0 ? "1" : "0" } ?? "unknown")",
            "CGDisplayIsActive=\(CGDisplayIsActive(display))", "CGDisplayIsAsleep=\(CGDisplayIsAsleep(display))",
            "brightness=\(brightness())", "InstantAmperage_mA=\(current)",
            "restoreBrightness=\(saved.map { String($0) } ?? "none")",
            "Voltage_mV=\(battery["Voltage"] ?? "unknown")",
            "ExternalConnected=\(battery["ExternalConnected"] ?? "unknown")",
        ].joined(separator: " "))
    }

    func failed(_ error: Error) {
        fputs("\(Date().ISO8601Format()) event=error \(error)\n", stderr)
        guard dim else { exit(1) }
    }

    func changed(_ closed: Bool) {
        let wasOpen = previousClosed == false
        previousClosed = closed
        do {
            if dim, wasOpen, closed, saved == nil {
                saved = try brightness(); try write(0)
            }
            if !closed {
                try restore()
            }
            try snapshot(closed ? "close" : "open")
        } catch { failed(error) }
    }
}

@MainActor
func run() throws {
    setbuf(stdout, nil)
    let args = Array(CommandLine.arguments.dropFirst())
    guard args == ["get"] || args == ["watch"] || args == ["watch", "--dim"] ||
        (args.count == 2 && args[0] == "set" && level(args[1]) != nil)
    else {
        throw Failure(description: "使い方: display-brightness.swift get | set <0...1> | watch [--dim]")
    }
    let probe = try Probe(dim: args == ["watch", "--dim"])
    defer { dlclose(probe.library) }
    if args[0] == "set" {
        try probe.write(level(args[1])!)
    }
    guard args[0] == "watch" else {
        try probe.snapshot(args[0])
        return
    }
    let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard root != 0 else { throw Failure(description: "IOPMrootDomain がない") }
    defer { IOObjectRelease(root) }
    guard let port = IONotificationPortCreate(kIOMainPortDefault)
    else { throw Failure(description: "通知ポートを作れない") }
    defer { IONotificationPortDestroy(port) }
    // 通知・タイマー・終了処理は、すべてメインキューで直列に行う。
    IONotificationPortSetDispatchQueue(port, .main)
    var notification: io_object_t = 0
    try check(
        IOServiceAddInterestNotification(port, root, kIOGeneralInterest, { pointer, _, message, argument in
            // IOPM.h の clamshell 通知。argument は参照先ではなくビットの組である。
            if message == 0xE003_4100 {
                MainActor.assumeIsolated {
                    let probe = Unmanaged<Probe>.fromOpaque(pointer!).takeUnretainedValue()
                    probe.changed(UInt(bitPattern: argument) & 1 != 0)
                }
            }
        }, Unmanaged.passUnretained(probe).toOpaque(), &notification),
        "IOServiceAddInterestNotification",
    )
    defer { IOObjectRelease(notification) }
    probe.previousClosed = try properties("IOPMrootDomain")["AppleClamshellState"] as? Bool
    try probe.snapshot("start")
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + 10, repeating: 10)
    timer.setEventHandler { do { try probe.snapshot("timer") } catch { probe.failed(error) } }
    timer.resume()
    let signals = [SIGINT, SIGTERM].map { number in
        signal(number, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
        source.setEventHandler {
            do { try probe.restore(); try probe.snapshot("signal-\(number)"); exit(0) }
            catch { fputs("\(Date().ISO8601Format()) event=error \(error)\n", stderr); exit(1) }
        }
        source.resume()
        return source
    }
    withExtendedLifetime((probe, timer, signals)) { CFRunLoopRun() }
}

do { try MainActor.assumeIsolated { try run() } } catch {
    fputs("\(Date().ISO8601Format()) event=error \(error)\n", stderr)
    exit(1)
}
