import AppKit
import CapsaicinPlatform
import Testing

struct TerminationReasonDetectorTests {
    private func quitEvent(
        reason: NSAppleEventDescriptor? = nil,
        eventClass: AEEventClass = AEEventClass(kCoreEventClass),
        eventID: AEEventID = AEEventID(kAEQuitApplication),
    ) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: eventClass, eventID: eventID, targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID),
        )
        if let reason {
            event.setParam(reason, forKeyword: AEKeyword(kAEQuitReason))
        }
        return event
    }

    @Test(
        "SPEC-LCY-002 合成 quit Event の文書化されたログアウト・再起動・システム終了理由を判定する",
        arguments: [kAEShutDown, kAERestart, kAEReallyLogOut],
    )
    func documentedSessionReasons(reason: OSType) {
        let event = quitEvent(reason: NSAppleEventDescriptor(typeCode: reason))
        #expect(TerminationReasonDetector.classify(explicitUserQuit: false, appleEvent: event) == .sessionEnd)
    }

    @Test("SPEC-LCY-002 材料のない終了、理由なし、型不正、未知の理由、quitAll は判定不能")
    func invalidEvidenceIsUnknown() {
        let events: [NSAppleEventDescriptor?] = [
            nil, quitEvent(), NSAppleEventDescriptor(string: "quit"),
            quitEvent(reason: NSAppleEventDescriptor(string: "rest")),
            quitEvent(reason: NSAppleEventDescriptor(int32: Int32(kAERestart))),
            quitEvent(reason: NSAppleEventDescriptor(enumCode: OSType(kAERestart))),
            quitEvent(reason: NSAppleEventDescriptor(typeCode: OSType(kAEQuitAll))),
            quitEvent(reason: NSAppleEventDescriptor(typeCode: OSType(kAELogOut))),
            quitEvent(reason: NSAppleEventDescriptor(typeCode: 0)),
            quitEvent(reason: NSAppleEventDescriptor(descriptorType: DescType(typeType), data: Data([0]))),
            quitEvent(reason: NSAppleEventDescriptor(
                descriptorType: DescType(typeType), data: Data([0x72, 0x65, 0x73, 0x74, 0]),
            )),
            quitEvent(reason: NSAppleEventDescriptor(typeCode: OSType(kAERestart)), eventClass: 0),
            quitEvent(reason: NSAppleEventDescriptor(typeCode: OSType(kAERestart)), eventID: AEEventID(kAERestart)),
        ]
        for event in events {
            #expect(TerminationReasonDetector.classify(explicitUserQuit: false, appleEvent: event) == .unknown)
            #expect(TerminationReasonDetector.classify(explicitUserQuit: true, appleEvent: event) == .userQuit)
        }
    }

    @Test(
        "SPEC-LCY-002 同じ終了試行の明示的な利用者終了をセッション終了の材料より優先する",
        arguments: [kAEShutDown, kAERestart, kAEReallyLogOut],
    )
    func explicitUserQuitHasPriority(reason: OSType) {
        let event = quitEvent(reason: NSAppleEventDescriptor(typeCode: reason))
        #expect(TerminationReasonDetector.classify(explicitUserQuit: true, appleEvent: event) == .userQuit)
    }

    @Test("SPEC-LCY-002 前の終了試行や取り消された試行の材料を次に持ち越さない")
    func attemptsDoNotShareEvidence() {
        let event = quitEvent(reason: NSAppleEventDescriptor(typeCode: OSType(kAEShutDown)))
        #expect(TerminationReasonDetector.classify(explicitUserQuit: false, appleEvent: event) == .sessionEnd)
        #expect(TerminationReasonDetector.classify(explicitUserQuit: false, appleEvent: nil) == .unknown)
        #expect(TerminationReasonDetector.classify(explicitUserQuit: true, appleEvent: nil) == .userQuit)
        #expect(TerminationReasonDetector.classify(explicitUserQuit: false, appleEvent: nil) == .unknown)
    }
}
