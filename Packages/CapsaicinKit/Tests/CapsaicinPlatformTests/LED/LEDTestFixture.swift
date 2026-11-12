@testable import CapsaicinPlatform
import Foundation

@MainActor
final class LEDTestFixture {
    struct Device {
        var name: String
        var keyboard = true
        var transport: String? = "USB"
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
    var ticks: [HIDKeyboardMonitor.Change] = []
    var activeSchedules: Set<Int> = []
    var scheduleCancellations = 0
    var errors: [CapsLockLEDError] = []

    func makeMonitor() -> HIDKeyboardMonitor {
        HIDKeyboardMonitor(register: { callback in
            self.registrations += 1
            if self.monitorFails {
                throw CapsLockLEDError.keyboardMonitorCreationFailed
            }
            self.changes.append(callback)
            return { self.cancellations += 1 }
        }, schedule: { tick in
            let index = self.ticks.count
            self.ticks.append(tick)
            self.activeSchedules.insert(index)
            return {
                self.activeSchedules.remove(index)
                self.scheduleCancellations += 1
            }
        })
    }

    func makeClient() throws -> LEDClient {
        creations += 1
        if creationFails {
            throw CapsLockLEDError.clientCreationFailed
        }
        let devices = devices
        return LEDClient {
            self.enumerations += 1
            if self.enumerationFails {
                throw CapsLockLEDError.servicesUnavailable
            }
            return devices.map { device in
                LEDService(
                    registryID: nil,
                    isKeyboard: { device.keyboard },
                    transport: { device.transport as CFString? },
                    setMode: { mode in
                        self.writes.append(Write(device: device.name, mode: mode))
                        return !self.failedDevices.contains(device.name)
                    },
                )
            }
        }
    }

    func makeController() -> CapsLockLEDController {
        let controller = CapsLockLEDController(
            symbolAvailable: { self.available },
            makeClient: makeClient,
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
