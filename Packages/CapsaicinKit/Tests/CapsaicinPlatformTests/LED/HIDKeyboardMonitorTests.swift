@testable import CapsaicinPlatform
import Testing

@MainActor
struct HIDKeyboardMonitorTests {
    @Test("SPEC-LED-002 監視は明示的に開始し、開始・停止は冪等で、解放時に停止する")
    func lifecycle() throws {
        let fake = LEDTestFixture()
        var monitor: HIDKeyboardMonitor? = fake.makeMonitor()
        #expect(fake.registrations == 0)
        try monitor?.start {}
        try monitor?.start {}
        #expect(fake.registrations == 1)
        monitor?.stop()
        monitor?.stop()
        #expect(fake.cancellations == 1)
        try monitor?.start {}
        weak let released = monitor
        monitor = nil
        #expect(released == nil)
        #expect(fake.cancellations == 2)
    }

    @Test("SPEC-LED-002 開始失敗の後も再開できる")
    func restartAfterFailure() throws {
        let fake = LEDTestFixture()
        fake.monitorFails = true
        let monitor = fake.makeMonitor()
        #expect(throws: CapsLockLEDError.keyboardMonitorCreationFailed) { try monitor.start {} }
        fake.monitorFails = false
        try monitor.start {}
        #expect(fake.registrations == 2)
        monitor.stop()
        #expect(fake.cancellations == 1)
    }
}
