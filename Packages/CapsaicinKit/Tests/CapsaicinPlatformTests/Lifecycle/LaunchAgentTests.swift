@testable import CapsaicinPlatform
import Foundation
import ServiceManagement
import Testing

@MainActor
struct LaunchAgentTests {
    @Test("SPEC-LCY-001 SPEC-LCY-003 plist にログイン設定とクラッシュ時だけの再起動を指定する", arguments: [false, true])
    func propertyList(isDebug: Bool) throws {
        let fixture = LaunchAgentFixture()
        let agent = fixture.agent(isDebug: isDebug)
        let label = "io.github.koutyuke.capsaicin" + (isDebug ? ".debug" : "")
        #expect(agent.label == label)
        for enabled in [false, true] {
            let plist = try decode(agent.propertyList(launchAtLogin: enabled))
            #expect(plist.count == 6)
            #expect(plist["Label"] as? String == label)
            #expect(plist["ProgramArguments"] as? [String] == [fixture.executable.path])
            #expect(plist["RunAtLoad"] as? Bool == enabled)
            #expect(plist["KeepAlive"] as? [String: Bool] == ["Crashed": true])
            #expect(plist["ProcessType"] as? String == "Interactive")
            #expect(plist["LimitLoadToSessionType"] as? String == "Aqua")
        }
    }

    @Test("SPEC-LCY-005 plist を書いてから bootstrap、kickstart の順で要求する")
    func registration() async throws {
        try await withFixture { fixture in
            fixture.serviceStatus = .notRegistered
            let agent = fixture.agent()
            let result = await agent.registerAndStart(launchAtLogin: false)
            #expect(result == .ready)
            #expect(fixture.commands == [
                ["bootstrap", "gui/501", agent.plistURL.path],
                ["kickstart", "gui/501/\(agent.label)"],
            ])
            #expect(fixture.plistExistedAtCommand == [true, true])
            #expect(fixture.statusURLs.isEmpty)
            let plist = try decode(Data(contentsOf: agent.plistURL))
            #expect(plist["RunAtLoad"] as? Bool == false)
        }
    }

    @Test("SPEC-LCY-001 ログイン設定だけの更新は plist を置き換え、launchctl を実行しない")
    func loginSettingOnly() async throws {
        try await withFixture { fixture in
            let agent = fixture.agent()
            try agent.updateLaunchAtLogin(true)
            let enabled = try decode(Data(contentsOf: agent.plistURL))
            try agent.updateLaunchAtLogin(false)
            let disabled = try decode(Data(contentsOf: agent.plistURL))
            #expect(enabled["RunAtLoad"] as? Bool == true)
            #expect(disabled["RunAtLoad"] as? Bool == false)
            #expect((enabled.filter { $0.key != "RunAtLoad" } as NSDictionary)
                .isEqual(to: disabled.filter { $0.key != "RunAtLoad" }))
            #expect(fixture.commands.isEmpty)
            #expect(fixture.statusURLs.isEmpty)
        }
    }

    @Test("SPEC-LCY-005 書き込み失敗時は登録失敗を返し、起動を要求しない")
    func writeFailure() async throws {
        try await withFixture { fixture in
            try Data().write(to: fixture.directory)
            #expect(await fixture.agent().registerAndStart(launchAtLogin: false) == .registrationFailed)
            #expect(fixture.commands.isEmpty)
        }
    }

    @Test("SPEC-LCY-005 読み込み済みで bootstrap が失敗しても kickstart で起動でき、両方の失敗を区別する", arguments: [
        ([1], LaunchAgentStatus.ready),
        ([2], LaunchAgentStatus.launchFailed),
        ([1, 2], LaunchAgentStatus.registrationFailed),
    ])
    func commandFailure(failing: [Int], expected: LaunchAgentStatus) async throws {
        try await withFixture { fixture in
            fixture.failingCommands = Set(failing)
            fixture.serviceStatus = .requiresApproval
            #expect(await fixture.agent().registerAndStart(launchAtLogin: false) == expected)
            #expect(fixture.commands.count == 2)
            #expect(fixture.statusURLs.isEmpty)
        }
    }

    @Test("SPEC-LCY-005 launchd 由来では承認待ちだけを無効とみなす", arguments: [
        (SMAppService.Status.enabled, LaunchAgentStatus.ready),
        (.requiresApproval, .disabled),
        (.notRegistered, .ready),
        (.notFound, .ready),
    ])
    func authorization(status: SMAppService.Status, expected: LaunchAgentStatus) {
        let fixture = LaunchAgentFixture()
        fixture.serviceStatus = status
        let agent = fixture.agent()
        #expect(agent.restartStatus() == expected)
        #expect(fixture.statusURLs == [agent.plistURL])
        #expect(fixture.commands.isEmpty)
    }

    @Test("SPEC-LCY-005 XPC_SERVICE_NAME が自分のラベルと一致するときだけ launchd 由来とする")
    func launchOrigin() {
        let fixture = LaunchAgentFixture()
        let agent = fixture.agent()
        #expect(agent.wasLaunchedByLaunchd(environment: ["XPC_SERVICE_NAME": agent.label]))
        #expect(!agent.wasLaunchedByLaunchd(environment: [:]))
        #expect(!agent.wasLaunchedByLaunchd(environment: ["XPC_SERVICE_NAME": ""]))
        #expect(!agent.wasLaunchedByLaunchd(environment: ["XPC_SERVICE_NAME": "io.github.koutyuke.capsaicin"]))
        #expect(!agent.wasLaunchedByLaunchd(environment: ["XPC_SERVICE_NAME": agent.label + ".other"]))
    }

    private func decode(_ data: Data) throws -> [String: Any] {
        try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }
}

@MainActor
private final class LaunchAgentFixture {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../../.build/task008-launchagent-fixtures")
        .appendingPathComponent(UUID().uuidString).standardizedFileURL
    let executable = URL(fileURLWithPath: "/Applications/Capsaicin Test.app/Contents/MacOS/Capsaicin")
    var directory: URL {
        root.appendingPathComponent("LaunchAgents")
    }

    var commands: [[String]] = []
    var plistExistedAtCommand: [Bool] = []
    var statusURLs: [URL] = []
    var failingCommands: Set<Int> = []
    var serviceStatus: SMAppService.Status = .enabled

    func agent(isDebug: Bool = true) -> LaunchAgent {
        LaunchAgent(
            executableURL: executable, isDebug: isDebug, directory: directory, uid: 501,
            runLaunchctl: { arguments in
                self.commands.append(arguments)
                let file = self.directory.appendingPathComponent("io.github.koutyuke.capsaicin.debug.plist")
                self.plistExistedAtCommand.append(FileManager.default.fileExists(atPath: file.path))
                if self.failingCommands.contains(self.commands.count) {
                    throw CommandRunnerError.unsuccessfulExit(1)
                }
            },
            serviceStatus: { url in
                self.statusURLs.append(url)
                return self.serviceStatus
            },
        )
    }
}

@MainActor
private func withFixture(_ body: (LaunchAgentFixture) async throws -> Void) async throws {
    let fixture = LaunchAgentFixture()
    try FileManager.default.createDirectory(at: fixture.root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    try await body(fixture)
}
