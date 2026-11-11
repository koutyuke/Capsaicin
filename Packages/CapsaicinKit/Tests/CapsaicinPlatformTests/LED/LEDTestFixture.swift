@testable import CapsaicinPlatform

@MainActor
final class LEDTestFixture {
    struct Device {
        var name: String
        var keyboard = true
        var hasTransport = true
    }

    struct Write: Equatable {
        var device: String
        var mode: String
    }

    var available = true
    var creationFails = false
    var enumerationFails = false
    var monitorFails = false
    var failedDevices: Set<String> = []
    var devices: [Device] = [.init(name: "internal"), .init(name: "external")]
    var writes: [Write] = []
    var creations = 0
    var enumerations = 0
    var registrations = 0
    var cancellations = 0
    var changes: [HIDKeyboardMonitor.Change] = []
    var errors: [CapsLockLEDError] = []

    func makeMonitor() -> HIDKeyboardMonitor {
        HIDKeyboardMonitor { callback in
            self.registrations += 1
            if self.monitorFails {
                throw CapsLockLEDError.keyboardMonitorCreationFailed
            }
            self.changes.append(callback)
            return { self.cancellations += 1 }
        }
    }

    func makeController() -> CapsLockLEDController {
        let controller = CapsLockLEDController(
            symbolAvailable: { self.available },
            makeClient: {
                self.creations += 1
                if self.creationFails {
                    throw CapsLockLEDError.clientCreationFailed
                }
                let devices = self.devices
                return LEDClient {
                    self.enumerations += 1
                    if self.enumerationFails {
                        throw CapsLockLEDError.servicesUnavailable
                    }
                    return devices.map { device in
                        LEDService(
                            registryID: nil,
                            isKeyboard: { device.keyboard },
                            hasTransport: { device.hasTransport },
                            setMode: { mode in
                                self.writes.append(Write(device: device.name, mode: mode))
                                return !self.failedDevices.contains(device.name)
                            },
                        )
                    }
                }
            },
            monitor: makeMonitor(),
        )
        controller.onReapplyFailure = { error in
            if let error = error as? CapsLockLEDError {
                self.errors.append(error)
            }
        }
        return controller
    }
}
