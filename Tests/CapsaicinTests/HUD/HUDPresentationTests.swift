import Testing

@MainActor
struct HUDPresentationTests {
    @Test("SPEC-HUD-006 置き換えは最後の内容だけを持ち、出る途中からも消さずに戻る")
    func latestContent() {
        let presentation = HUDPresentation()
        for phase: HUDPhase in [.hidden, .entering, .holding, .exiting] {
            presentation.phase = phase
            for index in 0 ..< 10 {
                let content = HUDContent(symbol: "capslock", state: "\(index)")
                presentation.replace(content, measuredWidth: 300)
                #expect(presentation.content == content)
                #expect(presentation.phase == phase)
                #expect(presentation.entryDuration == phase.replacementDuration)
            }
            #expect(presentation.content.state == "9")
        }
    }

    @Test("SPEC-HUD-004 幅は200〜420 ptに収める")
    func widthBounds() {
        let presentation = HUDPresentation()
        let content = HUDContent(symbol: "capslock", state: "")
        for (measured, expected) in [(100.0, 200.0), (300, 300), (800, 420)] {
            presentation.replace(content, measuredWidth: measured)
            #expect(Double(presentation.width) == expected)
        }
    }
}
