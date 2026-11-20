import AppKit
import CapsaicinCore
import SwiftUI

extension Image {
    init(symbol name: String, bundle: Bundle) {
        self = name.hasPrefix("custom.") ? Image(name, bundle: bundle) : Image(systemName: name)
    }
}

private extension VerticalAlignment {
    /// 項目名の中心。説明文があっても、アイコンと右の操作を項目名の行にそろえる。
    enum TitleCenter: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
            dimensions[VerticalAlignment.center]
        }
    }

    static var titleCenter: VerticalAlignment {
        VerticalAlignment(TitleCenter.self)
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    var subtitle: String?
    var help = ""
    var symbol: String?
    var child = false
    var enabled = true
    /// 空でなければ、アイコンを注意の記号にし、この文を読み上げる。
    var warningLabel = ""
    var controlAccessibilityLabel: String?
    @ViewBuilder var content: () -> Content
    /// 説明文のリンクを押せるよう、Markdown として読む。注意と説明を分ける改行は残す。
    private var helpText: AttributedString {
        (try? AttributedString(markdown: help, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(help)
    }

    var body: some View {
        HStack(alignment: .titleCenter) {
            HStack(alignment: .titleCenter, spacing: 8) {
                if let symbol = warningLabel.isEmpty ? symbol : "exclamationmark.triangle.fill" {
                    Image(symbol: symbol, bundle: Bundle(for: SettingsWindowController.self))
                        .foregroundStyle(symbol == "exclamationmark.triangle.fill" ? Color.orange : Color.secondary)
                        .frame(width: 20)
                        .accessibilityLabel(warningLabel)
                        .accessibilityHidden(warningLabel.isEmpty)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).foregroundStyle(enabled ? .primary : .secondary)
                        .disabled(!enabled)
                        .alignmentGuide(.titleCenter) { $0[VerticalAlignment.center] }
                    if let subtitle {
                        Text(subtitle).font(.callout).foregroundStyle(.secondary)
                            .lineLimit(1).help(subtitle)
                    }
                    if !help.isEmpty {
                        Text(helpText).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, child ? 28 : 0)
            // システム設定と同じく、折り返した説明文と右の操作の間を広めに空ける。
            Spacer(minLength: 24)
            content().disabled(!enabled)
                .accessibilityLabel(controlAccessibilityLabel ?? title).accessibilityHint(String(helpText.characters))
        }
        .contentShape(Rectangle())
    }
}

/// システム設定の各画面の先頭にある説明のカードと同じ形で、セクションが何のためにあるかを伝える。
struct SettingsIntroCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.tint)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: symbol).foregroundStyle(.white)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(message).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsDurationField: View {
    @Binding var value: TimerDuration
    @State private var input: DurationInput

    init(value: Binding<TimerDuration>) {
        _value = value
        _input = State(initialValue: DurationInput(value.wrappedValue))
    }

    var body: some View {
        DurationField(input: $input)
            .onChange(of: input) { _, input in
                if let duration = input.value, duration != value {
                    value = duration
                }
            }
            .onChange(of: value) { _, value in
                if input.value != value {
                    input = DurationInput(value)
                }
            }
    }
}

struct SettingsCopyButton: View {
    let path: String
    @State private var copied = false
    @State private var reset: Task<Void, Never>?
    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
            copied = true
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
                .announcement: SettingsSection.controls.text("cli.path.copied.a11y"),
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ])
            reset?.cancel()
            reset = Task {
                do { try await Task.sleep(for: .milliseconds(1500)); copied = false } catch { return }
            }
        } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
            .buttonStyle(.borderless)
            .help(SettingsSection.controls.text("cli.path.copy.a11y"))
            .accessibilityLabel(SettingsSection.controls.text("cli.path.copy.a11y"))
            .onDisappear { reset?.cancel() }
    }
}

struct SettingsSidebarIcon: View {
    let image: Image
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        // サイドバーが既定で描くアクセントカラーのアイコンは、ウインドウがアクティブな間、
        // Mission Control の開閉の遷移で点滅し GPU の負荷を上げる。SwiftUI だけの最小構成でも起きる。
        // 色を明示すると起きないため、既定ならアクセントカラーになる場面（アクティブで未選択の行）だけ塗る。
        if appearsActive, prominence != .increased {
            image.foregroundStyle(.tint)
        } else {
            image
        }
    }
}

struct SettingsSidebarSpacer: NSViewRepresentable {
    let availableHeight: CGFloat

    func makeNSView(context _: Context) -> SpacerView {
        SpacerView()
    }

    func updateNSView(_ view: SpacerView, context _: Context) {
        view.availableHeight = availableHeight
        view.updateHeight()
    }

    final class SpacerView: NSView {
        var availableHeight: CGFloat = 0
        private var height: CGFloat = 0
        private var padding: CGFloat = 0
        private var rowHeights: [CGFloat] = []
        private weak var observedRow: NSTableRowView?
        private var updateScheduled = false

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: height)
        }

        override func layout() {
            super.layout()
            updateHeight()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateHeight()
        }

        @objc private func rowFrameChanged(_: Notification) {
            guard !updateScheduled else { return }
            updateScheduled = true
            // 行のフレーム通知は表の再配置中にも届くため、残りの行の高さが確定してから読む。
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                updateScheduled = false
                updateHeight()
            }
        }

        func updateHeight() {
            guard let scroll = enclosingScrollView, let table = scroll.documentView as? NSTableView,
                  table.numberOfRows == SettingsSection.allCases.count + 1
            else { return }
            if let row = table.rowView(atRow: 4, makeIfNecessary: false), observedRow !== row {
                NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)
                observedRow = row
                // 表が見える高さまで伸びたままでも、上の行の高さが変われば空き行の原点は動く。
                row.postsFrameChangedNotifications = true
                NotificationCenter.default.addObserver(self, selector: #selector(rowFrameChanged(_:)),
                                                       name: NSView.frameDidChangeNotification, object: row)
            }
            // SwiftUI の contentSize にはツールバー由来の余白も混ざるため、システム設定に従う実際の行の高さを読む。
            let nextRowHeights = (0 ..< table.numberOfRows).filter { $0 != 4 }.map { table.rect(ofRow: $0).height }
            if nextRowHeights != rowHeights {
                rowHeights = nextRowHeights
                // 古い余白で空き行を短くしすぎると測り直せないため、一度広げて実際の余白を測る。
                padding = 0
            }
            let rowsHeight = rowHeights.reduce(CGFloat.zero, +)
            // 表は行のほかにサイドバー既定の余白を持ち、これも引かないとはみ出してスクロールする。
            // 内容が見える高さより短いと表は見える高さまで伸びて余白を測れないので、はみ出しているときに測って覚える。
            let visibleHeight =
                scroll.contentView.bounds.height - scroll.contentInsets.top - scroll.contentInsets.bottom
            if table.bounds.height > visibleHeight + 0.5 {
                padding = table.bounds.height - rowsHeight - table.rect(ofRow: 4).height
            }
            let next = max(0, availableHeight - rowsHeight - padding)
            guard next != height else { return }
            height = next
            invalidateIntrinsicContentSize()
        }
    }
}
