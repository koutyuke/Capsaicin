import AppKit
import SwiftUI

enum HUDPhase {
    case hidden, entering, holding, exiting

    var replacementDuration: Double {
        self == .hidden ? 0.20 : (self == .exiting ? 0.15 : 0)
    }
}

@MainActor @Observable
final class HUDPresentation {
    var content = HUDContent(symbol: "capslock", state: "")
    var phase = HUDPhase.hidden
    var width: CGFloat = 200
    var entryDuration = 0.20

    func replace(_ content: HUDContent, measuredWidth: CGFloat) {
        entryDuration = phase.replacementDuration
        // 表示中は、カプセルを中央に置く位置まで含めて同じアニメーションで補間する。
        // 消えている間は、文字のトランジションが持つアニメーションも含めて動かさない。
        var transaction = Transaction(animation: .timingCurve(0.2, 0, 0, 1, duration: 0.20))
        transaction.disablesAnimations = phase == .hidden
        withTransaction(transaction) {
            self.content = content
            width = min(420, measuredWidth)
        }
    }
}

struct HUDView: View {
    var presentation: HUDPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HUDLabel(content: presentation.content, reduceMotion: reduceMotion, increasedContrast: contrast == .increased)
            // 差し替えた文字を最終位置に置かず、アイコンと1つの行として一緒に動かす。
            .geometryGroup()
            .frame(width: presentation.width, height: 48)
            .clipShape(Capsule())
            .background {
                if reduceTransparency {
                    Capsule().fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    Color.clear.glassEffect(.regular, in: Capsule())
                }
            }
            .overlay {
                if reduceTransparency || contrast == .increased {
                    Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
            .animation(
                presentation.phase == .exiting
                    ? .timingCurve(0.4, 0, 1, 1, duration: 0.30)
                    : .timingCurve(0.2, 0, 0, 1, duration: presentation.entryDuration),
            ) {
                $0.opacity(presentation.phase == .hidden || presentation.phase == .exiting ? 0 : 1)
                    .scaleEffect(reduceMotion ? 1 :
                        (presentation.phase == .hidden ? 0.96 : (presentation.phase == .exiting ? 0.98 : 1)))
                    .offset(y: !reduceMotion && presentation.phase == .hidden ? 8 : 0)
            }
            .frame(width: 452, height: 80)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.content.announcement)
    }
}

struct HUDLabel: View {
    var content: HUDContent
    var reduceMotion = false
    var increasedContrast = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: content.symbol)
                .symbolRenderingMode(.monochrome)
                .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                .accessibilityHidden(true)
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Text(verbatim: content.state).fontWeight(.semibold).fixedSize()
                    if let detail = content.detail {
                        Text(verbatim: "·").foregroundStyle(Color(nsColor: .tertiaryLabelColor)).padding(.horizontal, 6)
                        Text(verbatim: detail)
                            .foregroundStyle(Color(nsColor: increasedContrast ? .labelColor : .secondaryLabelColor))
                            .truncationMode(.tail)
                            .monospacedDigit()
                    }
                }
                .id([content.state, content.detail])
                // 文字が消えて空になる瞬間を作らないよう、新旧を重ねて入れ替える。
                // 幅より長い時間をかけ、ぼかしが目で追えるようにする。
                .transition(HUDTextTransition(reduceMotion: reduceMotion).animation(.easeInOut(duration: 0.40)))
            }
        }
        .font(.title3)
        .foregroundStyle(Color(nsColor: .labelColor))
        .lineLimit(1)
        // SF Symbols は形の外側に約 3 pt の空白を持つため、左だけ減らして見える余白を右と揃える。
        .padding(.leading, 17)
        .padding(.trailing, 20)
    }
}

private struct HUDTextTransition: Transition {
    var reduceMotion: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity || reduceMotion ? 0 : 8)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
