import AppKit
import CapsaicinCore
import SwiftUI

extension Image {
    init(symbol name: String, bundle: Bundle) {
        self = name.hasPrefix("custom.") ? Image(name, bundle: bundle) : Image(systemName: name)
    }
}

struct SettingsInfo: View {
    let title: String
    let help: String
    @State private var isOpen = false
    var body: some View {
        Button { isOpen.toggle() } label: {
            Image(systemName: "info.circle").imageScale(.small).foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(String(format: SettingsSection.general.text("help.a11y"), title))
        .popover(isPresented: $isOpen) {
            Text(help).font(.callout).padding(16).frame(idealWidth: 280).fixedSize(horizontal: false, vertical: true)
        }
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
    var body: some View {
        HStack {
            HStack(spacing: 8) {
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
                    if let subtitle {
                        Text(subtitle).font(.callout).foregroundStyle(.secondary)
                            .lineLimit(1).help(subtitle)
                    }
                }
                if !help.isEmpty {
                    SettingsInfo(title: title, help: help)
                }
            }
            .padding(.leading, child ? 28 : 0)
            Spacer()
            content().disabled(!enabled)
                .accessibilityLabel(controlAccessibilityLabel ?? title).accessibilityHint(help)
        }
        .contentShape(Rectangle())
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
