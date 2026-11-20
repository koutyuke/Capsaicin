import Testing

extension SettingsTests {
    @Test("SPEC-SET-009 LED のイラストは点いた直後だけ輪を出し、点灯中は明るさを揺らさない")
    func ledIllustration() {
        #expect(FeedbackCycle.ledLevel(0) == 0 && FeedbackCycle.pings(0).isEmpty)
        #expect(FeedbackCycle.ledLevel(0.1) == 0.5)
        for time in stride(from: 0.2, to: FeedbackCycle.offAt, by: 0.1) {
            #expect(FeedbackCycle.ledLevel(time) == 1)
        }
        #expect(FeedbackCycle.pings(1).count == 1 && FeedbackCycle.pings(2.5).count == 1)
        #expect(FeedbackCycle.pings(4).isEmpty)
        #expect(FeedbackCycle.ledLevel(FeedbackCycle.offAt + 0.4) == 0 && FeedbackCycle.ledLevel(7.9) == 0)
        #expect(FeedbackCycle.ledLevel(nil) == 1 && FeedbackCycle.pings(nil).isEmpty)
    }

    @Test("SPEC-SET-009 HUD のイラストはオンとオフに切り替わるたびに HUD を出して消し、止めた絵では出したままにする")
    func hudIllustration() {
        #expect(FeedbackCycle.isOn(1) && !FeedbackCycle.isOn(6) && FeedbackCycle.isOn(nil))
        #expect(FeedbackCycle.hud(1).opacity == 1 && FeedbackCycle.hud(6).opacity == 1)
        for time in [0.05, 3, FeedbackCycle.offAt + 0.05, 7.5] {
            #expect(FeedbackCycle.hud(time).opacity == 0)
        }
        #expect(FeedbackCycle.hud(nil) == FeedbackCycle.HUDMotion(opacity: 1, scale: 1, offset: 0))
    }
}
