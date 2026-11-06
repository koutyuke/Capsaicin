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
        self.content = content
        width = min(420, max(200, measuredWidth))
    }
}

struct HUDView: View {
    var presentation: HUDPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HUDLabel(content: presentation.content, reduceMotion: reduceMotion, increasedContrast: contrast == .increased)
            .frame(width: presentation.width, height: 48)
            .background {
                if reduceTransparency {
                    Capsule().fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    HUDGlass()
                }
            }
            .overlay {
                if reduceTransparency || contrast == .increased {
                    Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
            .animation(.timingCurve(0.2, 0, 0, 1, duration: 0.20), value: presentation.width)
            .opacity(presentation.phase == .hidden || presentation.phase == .exiting ? 0 : 1)
            .scaleEffect(reduceMotion ? 1 :
                (presentation.phase == .hidden ? 0.96 : (presentation.phase == .exiting ? 0.98 : 1)))
            .offset(y: !reduceMotion && presentation.phase == .hidden ? 8 : 0)
            .animation(
                presentation.phase == .exiting
                    ? .timingCurve(0.4, 0, 1, 1, duration: 0.30)
                    : .timingCurve(0.2, 0, 0, 1, duration: presentation.entryDuration),
                value: presentation.phase,
            )
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
            .contentTransition(.opacity)
        }
        .font(.title3)
        .foregroundStyle(Color(nsColor: .labelColor))
        .lineLimit(1)
        .padding(.horizontal, 20)
        .animation(.linear(duration: 0.15), value: content)
    }
}

private struct HUDGlass: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        view.cornerRadius = 24
        return view
    }

    func updateNSView(_: NSGlassEffectView, context _: Context) {}
}
