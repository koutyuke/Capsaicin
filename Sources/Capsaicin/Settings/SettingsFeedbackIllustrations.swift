import AppKit
import SwiftUI

/// 「フィードバック」の各セクションの先頭に置く、説明文とイラストのカード。
struct SettingsFeedbackBanner<Illustration: View>: View {
    let text: String
    @ViewBuilder var illustration: () -> Illustration

    var body: some View {
        HStack(spacing: 16) {
            Text(text).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            // システム設定と同じく、イラストはカードの右端と上下端まで広げ、カードの角で切り取らせる。
            // 負の余白は、grouped の Form が行に持たせる余白（上下左右 10 pt）を打ち消す。
            illustration().frame(width: 200, height: 116, alignment: .topLeading)
                .padding(.trailing, -10).padding(.vertical, -10)
                .accessibilityHidden(true)
        }
    }
}

/// LED と HUD のイラストが同じ周期で動くよう、共通の時計から求めた1周期の中の経過秒から、各部の状態を決める。
/// 周期の前半はスリープ防止がオン、後半はオフの場面を描く。経過秒が nil なら、オンの場面の止めた絵にする。
enum FeedbackCycle {
    static let period = 8.0
    static let offAt = 5.0
    private static let pingStarts = [0.2, 2.2]
    private static let pingDuration = 1.6

    static func isOn(_ time: Double?) -> Bool {
        time.map { $0 < offAt } ?? true
    }

    /// LED の明るさ（0〜1）。オンになると 0.2 秒で点き、オフになると 0.3 秒で消える。点灯中は揺らさない。
    static func ledLevel(_ time: Double?) -> Double {
        guard let time else { return 1 }
        return time < offAt ? min(time / 0.2, 1) : max(1 - (time - offAt) / 0.3, 0)
    }

    /// 点いた直後だけ広がる輪の進み具合（0〜1）。止めた絵では輪を出さない。
    static func pings(_ time: Double?) -> [Double] {
        guard let time else { return [] }
        return pingStarts.map { (time - $0) / pingDuration }.filter { (0 ... 1).contains($0) }
    }

    /// HUD の不透明度、拡大率、縦のずれ。切り替えの 0.1 秒後から、HUD 本体と同じ時間（入る 0.20 秒、留まる 1.6 秒、
    /// 出る 0.30 秒）で動く。止めた絵では出ている状態にする。
    struct HUDMotion: Equatable {
        var opacity: Double
        var scale: Double
        var offset: Double
    }

    static func hud(_ time: Double?) -> HUDMotion {
        let elapsed = time.map { $0 - ($0 < offAt ? 0.1 : offAt + 0.1) } ?? 1
        guard elapsed >= 0, elapsed < 2.1 else { return HUDMotion(opacity: 0, scale: 0.96, offset: 2) }
        let entering = easeOut(elapsed / 0.2)
        let exiting = easeIn((elapsed - 1.8) / 0.3)
        return HUDMotion(
            opacity: entering * (1 - exiting),
            scale: elapsed < 0.2 ? 0.96 + 0.04 * entering : 1 - 0.02 * exiting,
            offset: 2 * (1 - entering),
        )
    }

    static func easeOut(_ progress: Double) -> Double {
        1 - pow(1 - min(max(progress, 0), 1), 3)
    }

    private static func easeIn(_ progress: Double) -> Double {
        pow(min(max(progress, 0), 1), 3)
    }
}

private struct FeedbackTimeline<Content: View>: View {
    @ViewBuilder var content: (_ time: Double?) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        // 視差効果を減らす設定では止めた絵（nil）にする。ウインドウが非アクティブの間は GPU を使い続けないよう止める。
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion || !appearsActive)) { context in
            content(reduceMotion ? nil
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: FeedbackCycle.period))
        }
    }
}

/// キーボードの左側を描き、Caps Lock の LED を点灯・消灯させる。点いた直後だけ輪を広げ、その後は点いたまま保つ。
/// 実際の LED は点滅しないので、点灯中に明るさを揺らさない。
struct LEDIllustration: View {
    var body: some View {
        FeedbackTimeline { time in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(.quinary)
                    .frame(width: 260, height: 130)
                VStack(alignment: .leading, spacing: 5) {
                    keys(first: 36)
                    keys(first: 46).overlay(alignment: .topLeading) { led(time: time).offset(x: 5, y: 5) }
                        .zIndex(1)
                    keys(first: 58)
                }.padding(8)
            }
            .offset(x: 16, y: 16)
        }
    }

    private func keys(first: CGFloat) -> some View {
        HStack(spacing: 5) {
            ForEach(0 ..< 7) { index in
                RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                    .frame(width: index == 0 ? first : 24, height: 24)
            }
        }
    }

    private func led(time: Double?) -> some View {
        let level = FeedbackCycle.ledLevel(time)
        let green = Color(nsColor: .systemGreen)
        return ZStack {
            ForEach(FeedbackCycle.pings(time), id: \.self) { progress in
                Circle().fill(green).scaleEffect(1 + 3 * FeedbackCycle.easeOut(progress)).opacity(0.45 * (1 - progress))
            }
            Circle().fill(.tertiary)
            Circle().fill(green).opacity(level).shadow(color: green.opacity(level), radius: 3)
        }.frame(width: 5, height: 5)
    }
}

/// 画面の縮小図を描き、メニューバーのアイコンの状態に合わせて画面下部に HUD を出し入れする。
struct HUDIllustration: View {
    private let bundle = Bundle(for: SettingsWindowController.self)

    var body: some View {
        FeedbackTimeline { time in
            let symbol = FeedbackCycle.isOn(time) ? "custom.capsaicin.led.fill" : "custom.capsaicin.led"
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6).fill(.quinary)
                menuBar(symbol: symbol)
                hud(symbol: symbol, time: time)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 12)
            }
            .frame(width: 160, height: 92)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func menuBar(symbol: String) -> some View {
        HStack(spacing: 4) {
            ForEach([6, 14, 10, 10], id: \.self) { width in
                Capsule().fill(.tertiary).frame(width: CGFloat(width), height: 3)
            }
            Spacer()
            Capsule().fill(.tertiary).frame(width: 6, height: 3)
            Image(symbol: symbol, bundle: bundle).font(.system(size: 8)).foregroundStyle(.secondary)
            Capsule().fill(.tertiary).frame(width: 14, height: 3)
        }
        .padding(.horizontal, 6).frame(height: 14)
        .background(.quaternary, in: UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6))
    }

    private func hud(symbol: String, time: Double?) -> some View {
        let motion = FeedbackCycle.hud(time)
        return HStack(spacing: 4) {
            Image(symbol: symbol, bundle: bundle).font(.system(size: 9))
            Capsule().fill(.tertiary).frame(width: 26, height: 3)
        }
        .padding(.horizontal, 8).frame(height: 16)
        .background(Capsule().fill(.background).shadow(color: .black.opacity(0.15), radius: 2, y: 1))
        .opacity(motion.opacity).scaleEffect(motion.scale).offset(y: motion.offset)
    }
}
