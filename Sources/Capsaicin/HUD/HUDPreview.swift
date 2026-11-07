#if DEBUG
    import AppKit
    import CapsaicinCore
    import SwiftUI

    /// パネルを出さずに、HUD の出現・置き換え・退場を Xcode の Canvas で再生する。
    private struct HUDPlayground: View {
        @State private var presentation = HUDPresentation()
        @State private var dismissal: Task<Void, Never>?

        var body: some View {
            VStack(spacing: 16) {
                HUDView(presentation: presentation)
                    // ガラスの見え方を確かめられるよう、背後に色を置く。
                    .background(.linearGradient(
                        colors: [.orange, .pink, .indigo],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ))
                HStack(alignment: .top, spacing: 24) {
                    ForEach(groups, id: \.title) { group in
                        VStack(alignment: .leading) {
                            Text(verbatim: group.title).font(.headline)
                            ForEach(group.contents.indices, id: \.self) { index in
                                let content = group.contents[index]
                                Button([content.state, content.detail].compactMap(\.self).joined(separator: " · ")) {
                                    show(content)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }

        /// `MenuHUDRouting.shouldPresent` が HUD を出すイベントについて、`HUDContent.make` の分岐を1つずつ通す。
        private var groups: [(title: String, contents: [HUDContent])] {
            let now = Date()
            let trigger = StartTrigger.user(.menu)
            let timer = BlockingSession(timeLimit: TimeLimit(date: now + 5400, source: .timer))
            let until = BlockingSession(timeLimit: TimeLimit(date: now + 5400, source: .specifiedTime))
            let battery = BatteryThreshold(percent: 20).map { BatteryCondition(threshold: $0, ignoresOnACPower: true) }
            func make(
                _ event: BlockingEvent, session: BlockingSession? = nil, batteryCondition: BatteryCondition? = nil,
                misalignments: Misalignments = [:], previousSession: BlockingSession? = nil,
            ) -> HUDContent? {
                HUDContent.make(
                    for: event,
                    status: BlockingStatus(
                        session: session, batteryCondition: batteryCondition,
                        misalignments: misalignments, isRecordUnsaved: false,
                    ),
                    previousSession: previousSession,
                    now: now,
                )
            }
            let rejections: [StartRejection] = [
                .batteryBelowThreshold, .helperNotInstalled, .mechanismsFailed([.systemSleepDisabled]), .recordNotSaved,
            ]
            let groups: [(String, [HUDContent?])] = [
                ("開始", [
                    make(.started(trigger)),
                    make(.started(trigger), session: timer),
                    make(.started(trigger), session: until),
                ]),
                ("開始できない", rejections.map { make(.startRejected(trigger, $0)) }),
                ("解除", [
                    make(.released(.user(.menu))),
                    make(.released(.timeLimit(.timer))),
                    make(.released(.timeLimit(.specifiedTime)), previousSession: until),
                    make(.released(.timeLimit(.specifiedTime))),
                    make(.released(.batteryBelowThreshold), batteryCondition: battery),
                    make(.released(.batteryBelowThreshold)),
                    make(.released(.user(.menu)), misalignments: [.led: .leftApplied]),
                ]),
            ]
            return groups.map { ($0, $1.compactMap(\.self)) }
        }

        /// `HUDPresenter.show` と同じ順と時間で phase を進める。あちらの時間を変えたら、こちらも合わせる。
        private func show(_ content: HUDContent) {
            dismissal?.cancel()
            let phase = presentation.phase
            presentation.replace(
                content,
                measuredWidth: NSHostingView(rootView: HUDLabel(content: content).fixedSize()).fittingSize.width,
            )
            presentation.phase = phase == .hidden ? .entering : .holding
            dismissal = Task { [presentation] in
                do {
                    try await Task.sleep(for: .seconds(phase.replacementDuration))
                    presentation.phase = .holding
                    try await Task.sleep(for: .seconds(1.6))
                    presentation.phase = .exiting
                    try await Task.sleep(for: .seconds(0.30))
                    presentation.phase = .hidden
                } catch {
                    // 次の表示が、表示時間を数え直す。
                }
            }
        }
    }

    #Preview("HUD") {
        HUDPlayground()
    }
#endif
