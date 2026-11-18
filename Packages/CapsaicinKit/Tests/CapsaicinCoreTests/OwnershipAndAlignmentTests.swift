@testable import CapsaicinCore
import Testing

struct OwnershipAndAlignmentTests {
    @Test(
        "SPEC-HLP-005 立てるときの規則は SleepDisabled と所有で決まる",
        arguments: [
            (false as Bool?, false, RaiseSleepDisabledAction.claimThenTurnOn),
            (false, true, .claimThenTurnOn),
            (true, true, .adoptOwn),
            (true, false, .leaveExternal),
            (nil, true, .failUnreadable),
        ],
    )
    func raise(sleepDisabled: Bool?, owned: Bool, expected: RaiseSleepDisabledAction) {
        #expect(SleepDisabledOwnership.raiseAction(sleepDisabled: sleepDisabled, owned: owned) == expected)
    }

    @Test("SPEC-HLP-005 下ろすときは、0 なら off せずに所有を外し、1 なら off し、読めなければ失敗とする")
    func lower() {
        #expect(SleepDisabledOwnership.lowerAction(sleepDisabled: false) == .releaseOwnership)
        #expect(SleepDisabledOwnership.lowerAction(sleepDisabled: true) == .turnOff)
        #expect(SleepDisabledOwnership.lowerAction(sleepDisabled: nil) == .failUnreadable)
    }

    private func misalignments(
        targets: Set<Mechanism>,
        observed: [Mechanism: Bool],
        owns: Bool = false,
    ) -> Misalignments {
        MechanismAlignment.misalignments(
            targets: targets, observed: observed, ownsSleepDisabled: owns, controllable: Set(Mechanism.allCases),
        )
    }

    @Test("SPEC-BLK-007 止めるべきなのに適用できていないものと、戻すべきなのに残っているものを向きで分ける")
    func directions() {
        let observed: [Mechanism: Bool] = [
            .idleSleepAssertion: false, .displaySleepAssertion: true, .led: true,
        ]
        let result = misalignments(targets: [.idleSleepAssertion, .led], observed: observed)
        #expect(result == [.idleSleepAssertion: .notApplied, .displaySleepAssertion: .leftApplied])
    }

    @Test("SPEC-BLK-007 状態が分からない仕組みは合っていないとみなす")
    func unknownIsMisaligned() {
        let result = misalignments(targets: [], observed: [.idleSleepAssertion: false, .displaySleepAssertion: false])
        #expect(result == [.led: .leftApplied])
    }

    @Test("SPEC-BLK-007 SPEC-HLP-005 外部の disablesleep は常に合っているとみなし、自分が立てたものだけを残っているとする")
    func sleepDisabledUsesOwnership() {
        let known: [Mechanism: Bool] = [
            .idleSleepAssertion: false, .displaySleepAssertion: false, .led: false,
            .systemSleepDisabled: true,
        ]
        #expect(misalignments(targets: [], observed: known, owns: false).isEmpty)
        #expect(misalignments(targets: [], observed: known, owns: true) == [.systemSleepDisabled: .leftApplied])
        var unread = known
        unread[.systemSleepDisabled] = nil
        #expect(misalignments(targets: [.systemSleepDisabled], observed: unread) == [.systemSleepDisabled: .notApplied])
    }
}
