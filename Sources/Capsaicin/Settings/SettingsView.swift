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
            List(
                selection: Binding<SettingsSection?>(
                    get: { selection.section },
                    set: {
                        if let section = $0 {
                            selection.section = section
                        }
                    },
                ),
            ) {
                ForEach(Array(SettingsSection.allCases.prefix(4))) { navigation($0) }
                SettingsSidebarSpacer(availableHeight: sidebarHeight)
                    .listRowInsets(EdgeInsets()).selectionDisabled().accessibilityHidden(true)
                ForEach(Array(SettingsSection.allCases.suffix(2))) { navigation($0) }
            }
            .listStyle(.sidebar)
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.containerSize.height - $0.contentInsets.top - $0.contentInsets.bottom
            } action: { _, height in
                sidebarHeight = height
            }
            .frame(width: 200)
            .navigationSplitViewColumnWidth(200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Form {
                switch selection.section {
                case .general: general
                case .sleep: sleep
                case .led: led
                case .controls: controls
                case .helper: helper
                case .about:
                    SettingsAboutContent(updater: model.app.updater, quit: quit, bundle: bundle)
                }
            }.formStyle(.grouped).toggleStyle(.switch)
                // grouped の Form は上に 20 pt の余白を持つ。システム設定と同じく、見出しの下から 12 pt にする。
                .contentMargins(.top, -8, for: .scrollContent)
                // About の下端はフッターで決めるため、Form 既定の下余白 20 pt を相殺する。
                .contentMargins(.bottom, selection.section == .about ? -20 : 0, for: .scrollContent)
                .navigationTitle(selection.section.title)
                .onChange(of: selection.section, initial: true) {
                    if selection.section == .about {
                        model.app.updater.refresh()
                    }
                }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            Button("") { NSApp.keyWindow?.performClose(nil) }.keyboardShortcut("w").hidden()
        }
    }

    private func navigation(_ section: SettingsSection) -> some View {
        Label { Text(section.title) } icon: {
            Image(symbol: section.symbol, bundle: Bundle(for: SettingsWindowController.self))
        }.tag(section)
    }

    @ViewBuilder
    private var general: some View {
        Section(SettingsSection.general.text("startup.group.title")) {
            toggle(.general, "launchAtLogin", \.launchesAtLogin, symbol: "power")
            SettingsRow(
                title: SettingsSection.general.text("resume.label"),
                help: SettingsSection.general.text("resume.help"),
                symbol: "arrow.clockwise",
            ) {
                Picker(SettingsSection.general.text("resume.label"), selection: binding(\.resumePolicy)) {
                    Text(SettingsSection.general.text("resume.option.never")).tag(ResumePolicy.never)
                    Text(SettingsSection.general.text("resume.option.app")).tag(ResumePolicy.afterAppRestart)
                    Text(SettingsSection.general.text("resume.option.appAndMac")).tag(
                        ResumePolicy.afterAppOrMacRestart,
                    )
                }.labelsHidden().pickerStyle(.menu)
            }
            if !model.app.willRestartAfterCrash {
                let key =
                    model.app.launchAgentStatus == .disabled ? "backgroundDisabled" : "restartUnavailable"
                SettingsRow(
                    title: SettingsSection.general.text(key + ".label"),
                    help: SettingsSection.general.text(key + ".help"),
                    symbol: "exclamationmark.triangle.fill",
                ) {}
            }
        }
        Section(SettingsSection.general.text("appearance.group.title")) {
            toggle(.general, "menuBarIcon", \.showsMenuBarIcon, symbol: "menubar.rectangle")
            toggle(.general, "dockIcon", \.showsDockIcon, symbol: "dock.rectangle")
        }
        toggle(.general, "hud", \.showsHUD, symbol: "capsule.bottomhalf.filled", help: true)
    }
}

extension SettingsView {
    @ViewBuilder
    private var sleep: some View {
        Section(SettingsSection.sleep.text("behavior.group.title")) {
            ForEach(model.displayedSleepRows.filter { $0.key == "display" }) { sleepRow($0) }
        }
        Section {
            ForEach(model.displayedSleepRows.filter { $0.key != "display" }) { sleepRow($0) }
        }
        release
    }

    private func sleepRow(_ row: SettingsSleepRow) -> some View {
        SettingsRow(
            title: SettingsSection.sleep.text(row.key + ".label"), help: row.help, symbol: row.symbol,
            warningLabel: row.warningLabel,
        ) {
            if row.key == "lidClose" {
                Picker(
                    SettingsSection.sleep.text(row.key + ".label"),
                    selection: Binding(get: { model.lidCloseChoice }, set: { choice in
                        Task { await model.changeLidClose(to: choice) }
                    }),
                ) {
                    ForEach(SettingsLidCloseChoice.allCases, id: \.self) { choice in
                        Text(SettingsSection.sleep.text("lidClose." + choice.rawValue)).tag(choice)
                    }
                }.labelsHidden().pickerStyle(.menu).disabled(model.isBusy)
            } else if let setting = row.setting {
                Toggle(
                    SettingsSection.sleep.text(row.key + ".label"),
                    isOn: Binding(
                        get: { row.isOn }, set: { value in Task { await model.changeSleep(row, to: value) } },
                    ),
                )
                .labelsHidden().disabled(model.isBusy)
            }
        }
    }

    var release: some View {
        let state = SettingsReleasePresentation(
            settings: model.app.settings, capabilities: model.app.capabilities,
        )
        return Group {
            Section(SettingsSection.sleep.text("release.group.title")) {
                toggle(.sleep, "timer", \.timerEnabled, symbol: "timer")
                SettingsRow(
                    title: SettingsSection.sleep.text("timer.duration.label"),
                    child: true, enabled: state.timerEnabled,
                ) {
                    SettingsDurationField(value: binding(\.timerDuration))
                }
            }
            Section {
                toggle(.sleep, "time", \.specifiedTimeEnabled, symbol: "clock", help: true)
                SettingsRow(
                    title: SettingsSection.sleep.text("time.value.label"),
                    child: true, enabled: state.timeEnabled,
                ) {
                    DatePicker(
                        SettingsSection.sleep.text("time.value.label"), selection: timeBinding,
                        displayedComponents: .hourAndMinute,
                    ).labelsHidden().datePickerStyle(.stepperField)
                        .monospacedDigit()
                }
            }
            if state.showsBattery {
                Section(SettingsSection.sleep.text("battery.group.title")) {
                    toggle(
                        .sleep, "battery", \.batteryConditionEnabled, symbol: "battery.50percent",
                    )
                    SettingsRow(
                        title: SettingsSection.sleep.text("battery.threshold.label"),
                        child: true, enabled: state.batteryEnabled,
                    ) {
                        HStack {
                            Text(
                                String(
                                    format: SettingsSection.sleep.text("battery.threshold.value"),
                                    model.app.settings.batteryThreshold.percent,
                                ),
                            )
                            .monospacedDigit().foregroundStyle(.secondary)
                            Slider(
                                value: Binding(
                                    get: { Double(model.app.settings.batteryThreshold.percent) },
                                    set: {
                                        if let value = BatteryThreshold(percent: Int($0)) {
                                            model.change(
                                                \.batteryThreshold,
                                                to: value,
                                            )
                                        }
                                    },
                                ), in: Double(BatteryThreshold.allowedPercents.lowerBound)
                                    ... Double(BatteryThreshold.allowedPercents.upperBound),
                                step: Double(BatteryThreshold.step),
                            ) {
                                Text(SettingsSection.sleep.text("battery.threshold.label"))
                            } tick: {
                                $0.truncatingRemainder(dividingBy: 10) == 0 ? SliderTick($0) : nil
                            }
                            .labelsHidden().frame(width: 160)
                        }
                    }
                    toggle(
                        .sleep, "battery.ignoreOnAdapter", \.ignoresBatteryOnACPower,
                        child: true, enabled: state.batteryEnabled,
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var led: some View {
        if model.app.hasVirtualKeyboard {
            Section {
                SettingsRow(
                    title: SettingsSection.led.text("virtualKeyboard.label"),
                    help: SettingsSection.led.text("virtualKeyboard.help"),
                    symbol: "exclamationmark.triangle.fill",
                ) {}
            }
        }
        Section { toggle(.led, "enabled", \.notifiesWithLED, symbol: "custom.capsaicin.led.fill") }
    }

    @ViewBuilder
    private var controls: some View {
        Section(SettingsSection.controls.text("hotkey.group.title")) {
            SettingsRow(
                title: SettingsSection.controls.text("hotkey.label"),
                help: SettingsSection.controls.text("hotkey.help"),
                symbol: "command",
            ) {
                HotkeyRecorder(controller: hotkey)
            }
            if hotkey.hasError {
                Label {
                    Text(SettingsSection.controls.text("hotkey.error.taken"))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            }
        }
        Section(SettingsSection.controls.text("cli.group.title")) {
            toggle(.controls, "cli", \.acceptsCLIRequests, symbol: "terminal", help: true)
            SettingsRow(
                title: SettingsSection.controls.text("cli.path.label"),
                help: SettingsSection.controls.text("cli.path.help"),
                symbol: "folder",
            ) {
                let path = bundle.bundleURL.appendingPathComponent("Contents/Helpers/capsaicin").path
                Text(path).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled).help(path)
                SettingsCopyButton(path: path)
            }
        }
    }

    var helper: some View {
        Section {
            SettingsRow(
                title: SettingsSection.helper.text("status.label"),
                help: SettingsSection.helper.text("status.help"),
                symbol: "lock.shield",
            ) {
                switch model.helperState {
                case .notInstalled:
                    Text(SettingsSection.helper.text("status.notInstalled")).foregroundStyle(.secondary)
                case .unavailable:
                    Text(SettingsSection.helper.text("status.unavailable")).foregroundStyle(.secondary)
                case .requiresApproval:
                    Label {
                        Text(SettingsSection.helper.text("status.requiresApproval"))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                case .installed:
                    Label {
                        Text(SettingsSection.helper.text("status.usable"))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }
            SettingsRow(
                title: SettingsSection.helper.text("manage.label"), symbol: "wrench.and.screwdriver",
            ) {
                switch model.helperState {
                case .notInstalled: helperButton(.install)
                case .requiresApproval:
                    Button(SettingsSection.helper.text("openSystemSettings.button")) {
                        Task { await model.manage(.install) }
                    }.buttonStyle(.bordered).disabled(model.isBusy)
                    helperButton(.remove)
                case .installed: helperButton(.remove)
                case .unavailable: EmptyView()
                }
            }
        }
    }
}

extension SettingsView {
    private func helperButton(_ operation: HelperManagementOperation) -> some View {
        Button(SettingsSection.helper.text(SettingsModel.operationKey(operation) + ".button")) {
            Task { await model.manage(operation) }
        }.buttonStyle(.bordered).disabled(model.isBusy)
    }

    private func toggle(
        _ section: SettingsSection,
        _ key: String,
        _ setting: WritableKeyPath<CapsaicinCore.Settings, Bool>,
        symbol: String? = nil,
        help: Bool = false,
        child: Bool = false,
        enabled: Bool = true,
    ) -> some View {
        SettingsRow(
            title: section.text(key + ".label"), help: help ? section.text(key + ".help") : "",
            symbol: symbol,
            child: child, enabled: enabled,
        ) {
            Toggle(section.text(key + ".label"), isOn: binding(setting)).labelsHidden()
        }
    }

    private func binding<Value>(_ key: WritableKeyPath<CapsaicinCore.Settings, Value>) -> Binding<
        Value,
    > {
        Binding(get: { model.app.settings[keyPath: key] }, set: { model.change(key, to: $0) })
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let time = model.app.settings.specifiedTime
                return Calendar.current.date(
                    from: DateComponents(
                        year: 2001,
                        month: 1,
                        day: 1,
                        hour: time.hour,
                        minute: time.minute,
                    ),
                )!
            },
            set: {
                let values = Calendar.current.dateComponents([.hour, .minute], from: $0)
                if let hour = values.hour, let minute = values.minute,
                   let time = TimeOfDay(hour: hour, minute: minute)
                {
                    model.change(\.specifiedTime, to: time)
                }
            },
        )
    }
}
