import CapsaicinCore
import Foundation
import IOKit.pwr_mgt

public enum PowerPlatformError: Error, Equatable, Sendable {
    case ioKit(operation: String, code: Int32)
    case unavailable(String)
}

@MainActor
public final class PowerAssertions: PowerAssertionControlling {
    private var assertions: [AssertionKind: IOPMAssertionID] = [:]
    private let create: (CFString, CFString, UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn
    private let release: (IOPMAssertionID) -> IOReturn

    public convenience init() {
        self.init(create: { type, name, identifier in
            IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), name, identifier)
        }, release: { IOPMAssertionRelease($0) })
    }

    init(create: @escaping (CFString, CFString, UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn,
         release: @escaping (IOPMAssertionID) -> IOReturn)
    {
        self.create = create
        self.release = release
    }

    public func createAssertion(_ kind: AssertionKind) throws {
        guard assertions[kind] == nil else { return }
        let type = switch kind {
        case .preventUserIdleSystemSleep: kIOPMAssertionTypePreventUserIdleSystemSleep
        case .preventUserIdleDisplaySleep: kIOPMAssertionTypePreventUserIdleDisplaySleep
        }
        var identifier: IOPMAssertionID = 0
        let result = create(type as CFString, "Capsaicin" as CFString, &identifier)
        guard result == kIOReturnSuccess else {
            throw PowerPlatformError.ioKit(operation: "IOPMAssertionCreateWithName", code: result)
        }
        assertions[kind] = identifier
    }

    public func releaseAssertion(_ kind: AssertionKind) throws {
        guard let identifier = assertions[kind] else { return }
        let result = release(identifier)
        guard result == kIOReturnSuccess else {
            throw PowerPlatformError.ioKit(operation: "IOPMAssertionRelease", code: result)
        }
        assertions.removeValue(forKey: kind)
    }

    isolated deinit {
        for identifier in assertions.values {
            _ = release(identifier)
        }
    }
}
