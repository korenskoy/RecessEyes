//
//  AppSettings.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation
import Combine

/// Настройки приложения, хранящиеся в UserDefaults
class AppSettings: ObservableObject {
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let workInterval     = "ru.korenskoy.RecessEyes.workInterval"
        static let breakInterval    = "ru.korenskoy.RecessEyes.breakInterval"
        static let pausedApps       = "ru.korenskoy.RecessEyes.pausedApps"
        static let eyeDropsEnabled  = "ru.korenskoy.RecessEyes.eyeDropsEnabled"
        static let eyeDropsInterval = "ru.korenskoy.RecessEyes.eyeDropsInterval"
        static let preBreakWarning  = "ru.korenskoy.RecessEyes.preBreakWarning"
        static let breakChime       = "ru.korenskoy.RecessEyes.breakChime"
        static let softModeAfterSunset = "ru.korenskoy.RecessEyes.softModeAfterSunset"
    }

    // MARK: - Published Properties
    @Published var workInterval: Int     = 2700   // 45 мин
    @Published var breakInterval: Int    = 300    // 5 мин
    @Published var eyeDropsEnabled: Bool = true
    @Published var eyeDropsInterval: Int = 120    // 2 часа (в минутах)
    @Published var launchAtLogin: Bool   = false
    @Published var pausedApps: [String]  = []
    @Published var preBreakWarning: Bool = true
    @Published var breakChime: Bool      = true
    @Published var softModeAfterSunset: Bool = true

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        let ud = UserDefaults.standard

        let savedWork      = ud.integer(forKey: Keys.workInterval)
        let savedBreak     = ud.integer(forKey: Keys.breakInterval)
        let savedEyeDrops  = ud.integer(forKey: Keys.eyeDropsInterval)
        let savedApps      = ud.stringArray(forKey: Keys.pausedApps)

        if savedWork     > 0 { workInterval     = savedWork     }
        if savedBreak    > 0 { breakInterval    = savedBreak    }
        if savedEyeDrops > 0 { eyeDropsInterval = savedEyeDrops }
        // Bool: объект будет nil если ключ ещё не записан → оставляем дефолт true
        if ud.object(forKey: Keys.eyeDropsEnabled) != nil {
            eyeDropsEnabled = ud.bool(forKey: Keys.eyeDropsEnabled)
        }
        if ud.object(forKey: Keys.preBreakWarning) != nil {
            preBreakWarning = ud.bool(forKey: Keys.preBreakWarning)
        }
        if ud.object(forKey: Keys.breakChime) != nil {
            breakChime = ud.bool(forKey: Keys.breakChime)
        }
        if ud.object(forKey: Keys.softModeAfterSunset) != nil {
            softModeAfterSunset = ud.bool(forKey: Keys.softModeAfterSunset)
        }
        if let apps = savedApps { pausedApps = apps }

        // Читаем реальный статус из SMAppService
        launchAtLogin = LaunchAtLoginManager.isEnabled

        setupPersistence()
    }

    // MARK: - Private

    private func setupPersistence() {
        let ud = UserDefaults.standard

        $workInterval
            .dropFirst()
            .sink { ud.set($0, forKey: Keys.workInterval) }
            .store(in: &cancellables)

        $breakInterval
            .dropFirst()
            .sink { ud.set($0, forKey: Keys.breakInterval) }
            .store(in: &cancellables)

        $eyeDropsEnabled
            .dropFirst()
            .sink { ud.set($0, forKey: Keys.eyeDropsEnabled) }
            .store(in: &cancellables)

        $eyeDropsInterval
            .dropFirst()
            .sink { ud.set($0, forKey: Keys.eyeDropsInterval) }
            .store(in: &cancellables)

        $pausedApps
            .dropFirst()
            .sink { ud.set($0, forKey: Keys.pausedApps) }
            .store(in: &cancellables)

        $launchAtLogin
            .dropFirst()
            .sink { LaunchAtLoginManager.setEnabled($0) }
            .store(in: &cancellables)

        $preBreakWarning
            .dropFirst()
            .sink { ud.set($0, forKey: Keys.preBreakWarning) }
            .store(in: &cancellables)

        $breakChime
            .dropFirst()
            .sink { ud.set($0, forKey: Keys.breakChime) }
            .store(in: &cancellables)

        $softModeAfterSunset
            .dropFirst()
            .sink { ud.set($0, forKey: Keys.softModeAfterSunset) }
            .store(in: &cancellables)
    }
}
