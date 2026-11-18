import AppKit
import Testing

@MainActor
struct AppDelegateTests {
    private let releaseID = "io.github.koutyuke.capsaicin"
    private let debugID = "io.github.koutyuke.capsaicin.debug"
    private let copyURL = URL(fileURLWithPath: "/Applications/Capsaicin Copy.app")

    @Test("SPEC-LCY-009 自分、終了済み、別の bundle ID を除く")
    func ignoresOtherCandidates() async {
        let delegate = AppDelegate()
        let fixture = AppFixture()
        var composed = false
        delegate.launch(
            bundleIdentifier: releaseID, processIdentifier: 10,
            runningApplications: { identifier in
                #expect(identifier == releaseID)
                return [
                    Candidate(bundleIdentifier: releaseID, processIdentifier: 10),
                    Candidate(bundleIdentifier: releaseID, processIdentifier: 11, isTerminated: true),
                    Candidate(bundleIdentifier: debugID, processIdentifier: 12),
                ]
            },
            reopenAndTerminate: { _ in Issue.record("起動を続けるべき候補を開き直した") },
            makeRuntime: {
                composed = true
                return makeRuntime(fixture)
            },
        )
        await delegate.startup?.value
        #expect(composed)
        #expect(fixture.savedSettings.isEmpty)
    }

    @Test("SPEC-LCY-009 先行プロセスを開き直す経路ではランタイムを組み立てない", arguments: [true, false])
    func reopensExistingCopyWithoutStarting(hasBundleURL: Bool) {
        let delegate = AppDelegate()
        let fixture = AppFixture()
        let url = hasBundleURL ? copyURL : nil
        var reopened: [URL?] = []
        delegate.launch(
            bundleIdentifier: releaseID, processIdentifier: 10,
            runningApplications: { _ in
                [Candidate(bundleIdentifier: releaseID, processIdentifier: 11, bundleURL: url)]
            },
            reopenAndTerminate: { reopened.append($0.bundleURL) },
            makeRuntime: {
                Issue.record("二重起動でランタイムを組み立てた")
                return makeRuntime(fixture)
            },
        )
        #expect(reopened == [url])
        #expect(delegate.runtime == nil)
        #expect(delegate.startup == nil)
        #expect(delegate.applicationShouldTerminate(.shared) == .terminateNow)
    }

    @Test("SPEC-LCY-009 起動途中に開き直されたときは、起動完了後に設定画面を開く")
    func defersSettingsUntilStartupCompletes() async {
        let delegate = AppDelegate()
        let fixture = AppFixture()
        var opens = 0
        delegate.launch(
            bundleIdentifier: releaseID, processIdentifier: 10,
            runningApplications: { _ in [] },
            reopenAndTerminate: { _ in Issue.record("単独起動では開き直さない") },
            makeRuntime: { makeRuntime(fixture, openSettings: { opens += 1 }) },
        )
        let handlesReopen = delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false)
        #expect(!handlesReopen)
        #expect(opens == 0)
        await delegate.startup?.value
        #expect(opens == 1)
        #expect(fixture.savedSettings.isEmpty)
    }

    private func makeRuntime(_ fixture: AppFixture, openSettings: @escaping @MainActor () -> Void = {}) -> AppRuntime {
        AppRuntime(
            model: fixture.model,
            updateLaunchAtLogin: { _ in }, reregisterHelper: {},
            startServices: {}, stopServices: {}, openSettings: openSettings,
        )
    }
}

private struct Candidate: RunningApp {
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    var isTerminated = false
    var bundleURL: URL?
}
