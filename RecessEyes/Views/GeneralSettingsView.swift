//
//  GeneralSettingsView.swift
//  RecessEyes
//

import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var timerManager: TimerManager
    var timerViewModel: TimerViewModel  // @Observable

    @State private var showRestartAlert: Bool = false
    @State private var pendingLanguage: LanguageOption = .system

    enum LanguageOption: Hashable {
        case system
        case code(String)

        var storageValue: String? {
            switch self {
            case .system: return nil
            case .code(let c): return c
            }
        }

        static func from(_ stored: String?) -> LanguageOption {
            guard let s = stored else { return .system }
            return .code(s)
        }

        /// Display label: endonym (language's own native name) for code options,
        /// localized "System" for the system option.
        var displayLabel: String {
            switch self {
            case .system:     return String(localized: "language.system")
            case .code("en"): return "English"
            case .code("es"): return "Español"
            case .code("ru"): return "Русский"
            case .code("az"): return "Azərbaycan"
            case .code("fa"): return "فارسی"
            case .code:       return String(localized: "language.system")
            }
        }
    }

    // Sorted by endonym (native name): System, Azərbaycan, English, Español, Русский, فارسی
    private static let languageOptions: [LanguageOption] = [
        .system, .code("az"), .code("en"), .code("es"), .code("ru"), .code("fa")
    ]

    // MARK: - Bindings (unit conversions)

    private var workMinutes: Binding<Int> {
        Binding(
            get: { appSettings.workInterval / 60 },
            set: { appSettings.workInterval = max(1, $0) * 60 }
        )
    }

    private var breakSeconds: Binding<Int> {
        Binding(
            get: { appSettings.breakInterval },
            set: { appSettings.breakInterval = max(5, $0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero
                StatusHero(
                    timerManager: timerManager,
                    appSettings: appSettings,
                    disabledUntilDate: timerViewModel.disabledUntilDate
                )
                .padding(.bottom, 22)

                // Timer
                GroupLabel(key: "settings.section.timer")
                GroupCard {
                    SettingsRow(
                        icon: "timer", tone: DS.iconBlue,
                        title: "settings.work_interval",
                        sub: "settings.work_interval.sub"
                    ) {
                        ChevronStepper(value: workMinutes, range: 1...120, step: 1, unit: "unit.min")
                    }
                    RowDivider()
                    SettingsRow(
                        icon: "cup.and.saucer.fill", tone: DS.iconOrange,
                        title: "settings.break_length",
                        sub: "settings.break_length.sub"
                    ) {
                        ChevronStepper(value: breakSeconds, range: 5...600, step: 5, unit: "unit.sec")
                    }
                    RowDivider()
                    SettingsRow(
                        icon: "bell.fill", tone: DS.iconRed,
                        title: "settings.warning",
                        sub: "settings.warning.sub"
                    ) {
                        MacToggle(isOn: $appSettings.preBreakWarning)
                    }
                    RowDivider()
                    ExplainerRow()
                }
                .padding(.bottom, 18)

                // Eye care
                GroupLabel(key: "settings.section.eyecare")
                GroupCard {
                    SettingsRow(
                        icon: "drop.fill", tone: DS.iconPurple,
                        title: "settings.eyedrops",
                        sub: "settings.eyedrops.sub"
                    ) {
                        MacToggle(isOn: $appSettings.eyeDropsEnabled)
                    }
                    RowDivider()
                    SettingsRow(
                        icon: "timer", tone: DS.iconPurple,
                        title: "settings.eyedrops.interval",
                        sub: "settings.eyedrops.interval.sub"
                    ) {
                        ChevronStepper(
                            value: $appSettings.eyeDropsInterval,
                            range: 30...720, step: 30,
                            unit: "unit.min"
                        )
                    }
                    RowDivider()
                    SettingsRow(
                        icon: "moon.fill", tone: DS.iconPurple,
                        title: "settings.softmode",
                        sub: "settings.softmode.sub"
                    ) {
                        MacToggle(isOn: $appSettings.softModeAfterSunset)
                    }
                }
                .padding(.bottom, 18)

                // System
                GroupLabel(key: "settings.section.system")
                GroupCard {
                    SettingsRow(
                        icon: "power", tone: DS.iconGraphite,
                        title: "settings.launch_at_login",
                        sub: "settings.launch_at_login.sub"
                    ) {
                        MacToggle(isOn: $appSettings.launchAtLogin)
                    }
                    RowDivider()
                    SettingsRow(
                        icon: "speaker.wave.2.fill", tone: DS.iconGreen,
                        title: "settings.chime",
                        sub: "settings.chime.sub"
                    ) {
                        MacToggle(isOn: $appSettings.breakChime)
                    }
                    RowDivider()
                    SettingsRow(
                        icon: "globe", tone: DS.iconBlue,
                        title: "settings.language",
                        sub: "settings.language.sub"
                    ) {
                        PopupButton(
                            selection: Binding(
                                get: { LanguageOption.from(LanguageManager.currentOverride) },
                                set: { newValue in
                                    pendingLanguage = newValue
                                    LanguageManager.currentOverride = newValue.storageValue
                                    showRestartAlert = true
                                }
                            ),
                            items: Self.languageOptions
                        ) { option in
                            Text(verbatim: option.displayLabel)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .frame(minHeight: 580)
        .alert("language.restart_alert.message", isPresented: $showRestartAlert) {
            Button("language.restart_alert.button.restart") {
                LanguageManager.restartApp()
            }
            Button("language.restart_alert.button.later", role: .cancel) { }
        }
    }
}
