import AppKit
import CapsaicinCore
import CapsaicinPlatform
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel
    let hotkey: HotkeyController
    @Bindable var selection: SettingsSelection
    let quit: () -> Void
    var bundle: Bundle = .main
    @State private var sidebarHeight: CGFloat = 0

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<SettingsSection?>(get: { selection.section }, set: {
                if let section = $0 {
                    selection.section = section
                }
            })) {
                ForEach(Array(SettingsSection.allCases.prefix(5))) { navigation($0) }
                SettingsSidebarSpacer(availableHeight: sidebarHeight)
                    .listRowInsets(EdgeInsets()).selectionDisabled().accessibilityHidden(true)
                ForEach(Array(SettingsSection.allCases.suffix(2))) { navigation($0) }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(MenuContent.text("menu.quit", bundle: bundle), action: quit)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.containerSize.height - $0.contentInsets.top - $0.contentInsets.bottom
            } action: { _, height in
                sidebarHeight = height
            }
            .frame(width: 200)
            .navigationSplitViewColumnWidth(200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                if selection.section == .about {
                    about
                } else {
                    Form {
                        switch selection.section {
                        case .general: general
                        case .sleep: sleep
                        case .release: release
                        case .led: led
                        case .controls: controls
                        case .helper: helper
                        case .about: EmptyView()
                        }
                    }.formStyle(.grouped).toggleStyle(.switch)
                        // grouped の Form は上に 20 pt の余白を持つ。システム設定と同じく、見出しの下から 12 pt にする。
                        .contentMargins(.top, -8, for: .scrollContent)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            Button("") { NSApp.keyWindow?.performClose(nil) }.keyboardShortcut("w").hidden()
        }
    }

    private func navigation(_ section: SettingsSection) -> some View {
        Label(section.title, systemImage: section.symbol).tag(section)
    }

    private var general: some View {
        Section {
            toggle(.general, "launchAtLogin", \.launchesAtLogin)
            SettingsRow(
                title: SettingsSection.general.text("resume.label"),
                help: SettingsSection.general.text("resume.help"),
            ) {
                Picker(SettingsSection.general.text("resume.label"), selection: binding(\.resumePolicy)) {
                    Text(SettingsSection.general.text("resume.option.never")).tag(ResumePolicy.never)
                    Text(SettingsSection.general.text("resume.option.app")).tag(ResumePolicy.afterAppRestart)
                    Text(SettingsSection.general.text("resume.option.appAndMac")).tag(ResumePolicy.afterAppOrMacRestart)
                }.labelsHidden().pickerStyle(.menu)
            }
            toggle(.general, "hud", \.showsHUD, help: true)
            toggle(.general, "menuBarIcon", \.showsMenuBarIcon, help: true)
            toggle(.general, "dockIcon", \.showsDockIcon, help: true)
            if !model.app.willRestartAfterCrash {
                let key = model.app.launchAgentStatus == .disabled ? "backgroundDisabled" : "restartUnavailable"
                SettingsRow(title: SettingsSection.general.text(key + ".label"),
                            help: SettingsSection.general.text(key + ".help"))
                {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
        }
    }

    private var sleep: some View {
        Section {
            ForEach(model.sleepRows) { row in
                SettingsRow(title: SettingsSection.sleep.text(row.key + ".label"), help: row.help,
                            child: row.key == "lidDisplay", enabled: !row.dimsLabel,
                            warning: row.state == .onWithoutHelper)
                {
                    if row.key == "lidDisplay" {
                        Picker(SettingsSection.sleep.text(row.key + ".label"),
                               selection: binding(\.lidCloseDisplay))
                        {
                            Text(SettingsSection.sleep.text("lidDisplay.keepOn")).tag(LidCloseDisplay.keepOn)
                            Text(SettingsSection.sleep.text("lidDisplay.turnOff")).tag(LidCloseDisplay.turnOff)
                        }.labelsHidden().pickerStyle(.menu).disabled(!row.isEnabled || model.isBusy)
                    } else if let setting = row.setting {
                        Toggle(SettingsSection.sleep.text(row.key + ".label"), isOn: Binding(get: {
                            setting == \.blocksManualSleep && model.pendingManual || row.isOn
                        }, set: { value in Task { await model.changeSleep(row, to: value) } }))
                            .labelsHidden().disabled(!row.isEnabled || model.isBusy)
                    }
                }
            }
        }
    }

    private var release: some View {
        let state = SettingsReleasePresentation(settings: model.app.settings, capabilities: model.app.capabilities)
        return Group {
            Section(SettingsSection.release.text("time.group.title")) {
                toggle(.release, "timer", \.timerEnabled)
                SettingsRow(title: SettingsSection.release.text("timer.duration.label"),
                            help: state.timerEnabled ? "" : SettingsSection.release.text("timer.duration.help"),
                            child: true, enabled: state.timerEnabled)
                {
                    SettingsDurationField(value: binding(\.timerDuration))
                }
                toggle(.release, "time", \.specifiedTimeEnabled, help: true)
                SettingsRow(title: SettingsSection.release.text("time.value.label"),
                            help: state.timeEnabled ? "" : SettingsSection.release.text("time.value.help"),
                            child: true, enabled: state.timeEnabled)
                {
                    DatePicker(SettingsSection.release.text("time.value.label"), selection: timeBinding,
                               displayedComponents: .hourAndMinute).labelsHidden().datePickerStyle(.stepperField)
                        .monospacedDigit()
                }
            }
            if state.showsBattery {
                Section(SettingsSection.release.text("battery.group.title")) {
                    toggle(.release, "battery", \.batteryConditionEnabled, help: true)
                    SettingsRow(title: SettingsSection.release.text("battery.threshold.label"),
                                help: state.batteryEnabled ? "" : SettingsSection.release
                                    .text("battery.threshold.help"),
                                child: true, enabled: state.batteryEnabled)
                    {
                        HStack {
                            Text(String(format: SettingsSection.release.text("battery.threshold.value"),
                                        model.app.settings.batteryThreshold.percent))
                                .monospacedDigit().foregroundStyle(.secondary)
                            Slider(value: Binding(get: { Double(model.app.settings.batteryThreshold.percent) }, set: {
                                if let value = BatteryThreshold(percent: Int($0)) {
                                    model.change(
                                        \.batteryThreshold,
                                        to: value,
                                    )
                                }
                            }), in: 0 ... 100, step: 5) {
                                Text(SettingsSection.release.text("battery.threshold.label"))
                            } tick: { $0.truncatingRemainder(dividingBy: 10) == 0 ? SliderTick($0) : nil }
                                .labelsHidden().frame(width: 160)
                        }
                    }
                    toggle(.release, "battery.ignoreOnAdapter", \.ignoresBatteryOnACPower,
                           help: true, child: true, enabled: state.batteryEnabled)
                }
            }
        }
    }

    @ViewBuilder
    private var led: some View {
        if model.app.isKarabinerRunning {
            Section {
                SettingsRow(
                    title: SettingsSection.led.text("karabiner.label"),
                    help: SettingsSection.led.text("karabiner.help"),
                ) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
        }
        Section { toggle(.led, "enabled", \.notifiesWithLED) }
    }

    @ViewBuilder
    private var controls: some View {
        Section(SettingsSection.controls.text("hotkey.group.title")) {
            SettingsRow(
                title: SettingsSection.controls.text("hotkey.label"),
                help: SettingsSection.controls.text("hotkey.help"),
            ) {
                HotkeyRecorder(controller: hotkey)
            }
            if hotkey.hasError {
                Label {
                    Text(SettingsSection.controls.text("hotkey.error.taken"))
                } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
        }
        Section(SettingsSection.controls.text("cli.group.title")) {
            toggle(.controls, "cli", \.acceptsCLIRequests, help: true)
            SettingsRow(
                title: SettingsSection.controls.text("cli.path.label"),
                help: SettingsSection.controls.text("cli.path.help"),
            ) {
                let path = bundle.bundleURL.appendingPathComponent("Contents/Helpers/capsaicin").path
                Text(path).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled).help(path)
                SettingsCopyButton(path: path)
            }
        }
    }

    private var helper: some View {
        Section {
            SettingsRow(
                title: SettingsSection.helper.text("status.label"),
                help: SettingsSection.helper.text("status.help"),
            ) {
                switch model.helperState {
                case .notInstalled: Text(SettingsSection.helper.text("status.notInstalled")).foregroundStyle(.secondary)
                case .partial:
                    Label { Text(SettingsSection.helper.text("status.partial")) } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                case .installed:
                    Label { Text(SettingsSection.helper.text("status.installed")) } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }
            SettingsRow(title: SettingsSection.helper.text("manage.label")) {
                switch model.helperState {
                case .notInstalled: helperButton(.install)
                case .partial: helperButton(.repair); helperButton(.remove)
                case .installed: helperButton(.remove)
                }
            }
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

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: height)
        }

        override func layout() {
            super.layout()
            updateHeight()
        }

        func updateHeight() {
            guard let table = enclosingScrollView?.documentView as? NSTableView,
                  table.numberOfRows == SettingsSection.allCases.count + 1 else { return }
            // SwiftUI の contentSize にはツールバー由来の余白も混ざるため、システム設定に従う実際の行の高さを読む。
            let rowsHeight = (0 ..< table.numberOfRows).filter { $0 != 5 }
                .reduce(CGFloat.zero) { $0 + table.rect(ofRow: $1).height }
            let next = max(0, availableHeight - rowsHeight)
            guard next != height else { return }
            height = next
            invalidateIntrinsicContentSize()
        }
    }
}

private extension SettingsView {
    var about: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundle.bundlePath)).resizable().frame(width: 96, height: 96)
                .accessibilityLabel(SettingsSection.about.text("icon.a11y"))
            Text(verbatim: "Capsaicin").font(.title)
            Text(String(format: SettingsSection.about.text("version"),
                        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
                        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))
                .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func helperButton(_ operation: HelperManagementOperation) -> some View {
        Button(SettingsSection.helper.text(SettingsModel.operationKey(operation) + ".button")) {
            Task { await model.manage(operation) }
        }.buttonStyle(.bordered).disabled(model.isBusy)
    }

    private func toggle(
        _ section: SettingsSection,
        _ key: String,
        _ setting: WritableKeyPath<CapsaicinCore.Settings, Bool>,
        help: Bool = false,
        child: Bool = false,
        enabled: Bool = true,
    ) -> some View {
        SettingsRow(title: section.text(key + ".label"), help: help ? section.text(key + ".help") : "",
                    child: child, enabled: enabled)
        {
            Toggle(section.text(key + ".label"), isOn: binding(setting)).labelsHidden()
        }
    }

    private func binding<Value>(_ key: WritableKeyPath<CapsaicinCore.Settings, Value>) -> Binding<Value> {
        Binding(get: { model.app.settings[keyPath: key] }, set: { model.change(key, to: $0) })
    }

    private var timeBinding: Binding<Date> {
        Binding(get: {
            let time = model.app.settings.specifiedTime
            return Calendar.current.date(from: DateComponents(
                year: 2001,
                month: 1,
                day: 1,
                hour: time.hour,
                minute: time.minute,
            ))!
        }, set: {
            let values = Calendar.current.dateComponents([.hour, .minute], from: $0)
            if let hour = values.hour, let minute = values.minute, let time = TimeOfDay(hour: hour, minute: minute) {
                model.change(\.specifiedTime, to: time)
            }
        })
    }
}
