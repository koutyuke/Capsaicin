import CapsaicinCore
import Foundation
import IOKit.pwr_mgt

public enum PowerPlatformError: Error, Equatable, Sendable {
    case ioKit(operation: String, code: Int32)
    case unavailable(String)
}

/// 種類ごとに、このインスタンスが作ったアサーションを1つだけ所有する。
@MainActor
public final class PowerAssertions: PowerAssertionControlling {
    private struct Identity {
        let identifier: IOPMAssertionID
        let type: String
        let name: String
    }

    private enum Ownership {
        case held(Identity)
        case unknown(Identity?)
    }

    // 項目がない種類だけが未所有と確定している。失敗を「効果なし」とは扱わない。
    private var ownership: [AssertionKind: Ownership] = [:]
    private let create: (CFString, CFString, UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn
    private let release: (IOPMAssertionID) -> IOReturn
    private let copyProperties: (IOPMAssertionID) throws -> CFDictionary?

    public convenience init() {
        self.init(create: { type, name, identifier in
            IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), name, identifier)
        }, release: { IOPMAssertionRelease($0) }, copyProperties: {
            IOPMAssertionCopyProperties($0)?.takeRetainedValue()
        })
    }

    init(
        create: @escaping (CFString, CFString, UnsafeMutablePointer<IOPMAssertionID>) -> IOReturn,
        release: @escaping (IOPMAssertionID) -> IOReturn,
        copyProperties: @escaping (IOPMAssertionID) throws -> CFDictionary?,
    ) {
        self.create = create
        self.release = release
        self.copyProperties = copyProperties
    }

    public func createAssertion(_ kind: AssertionKind) throws {
        switch ownership[kind] {
        case .held:
            return
        case let .unknown(identity):
            guard let identity else { throw ownershipUnknown }
            let properties = try ownedProperties(identity)
            guard let level = properties[kIOPMAssertionLevelKey] as? NSNumber,
                  CFGetTypeID(level) == CFNumberGetTypeID(),
                  level == NSNumber(value: kIOPMAssertionLevelOn)
            else { throw ownershipUnknown }
            ownership[kind] = .held(identity)
            return
        case nil:
            break
        }
        let type = switch kind {
        case .preventUserIdleSystemSleep: kIOPMAssertionTypePreventUserIdleSystemSleep
        case .preventUserIdleDisplaySleep: kIOPMAssertionTypePreventUserIdleDisplaySleep
        }
        let name = "Capsaicin — \(type) — \(UUID().uuidString)"
        var identifier: IOPMAssertionID = 0
        let result = create(type as CFString, name as CFString, &identifier)
        guard result == kIOReturnSuccess else {
            // 出力 ID も応答の一部なので、作成失敗時には所有の根拠に使わない。
            ownership[kind] = .unknown(nil)
            throw PowerPlatformError.ioKit(operation: "IOPMAssertionCreateWithName", code: result)
        }
        ownership[kind] = .held(Identity(identifier: identifier, type: type, name: name))
    }

    public func releaseAssertion(_ kind: AssertionKind) throws {
        let identity: Identity
        switch ownership[kind] {
        case let .held(held):
            identity = held
        case let .unknown(unknown):
            guard let unknown else { throw ownershipUnknown }
            _ = try ownedProperties(unknown)
            identity = unknown
        case nil:
            return
        }
        let result = release(identity.identifier)
        guard result == kIOReturnSuccess else {
            ownership[kind] = .unknown(identity)
            throw PowerPlatformError.ioKit(operation: "IOPMAssertionRelease", code: result)
        }
        ownership.removeValue(forKey: kind)
    }

    private var ownershipUnknown: PowerPlatformError {
        .unavailable("IOPMAssertion ownership unknown")
    }

    private func ownedProperties(_ identity: Identity) throws -> NSDictionary {
        // nil は消滅だけでなく読み取り失敗でもある。ID は再利用されるため名前も照合する。
        guard let properties = try copyProperties(identity.identifier) as NSDictionary?,
              let name = properties[kIOPMAssertionNameKey] as? String,
              let type = properties[kIOPMAssertionTypeKey] as? String,
              name == identity.name, type == identity.type
        else { throw ownershipUnknown }
        return properties
    }

    isolated deinit {
        for state in ownership.values {
            switch state {
            case let .held(identity):
                _ = release(identity.identifier)
            case let .unknown(identity?):
                if (try? ownedProperties(identity)) != nil {
                    _ = release(identity.identifier)
                }
            case .unknown(nil):
                break
            }
        }
    }
}
