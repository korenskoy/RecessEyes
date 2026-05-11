//
//  PausedAppsManager.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation
import AppKit
import Combine

/// Менеджер списка приложений для паузы (хранение через UserDefaults)
class PausedAppsManager: ObservableObject {
    // MARK: - Published Properties

    /// Полный список приложений для отображения в Settings
    @Published var installedApps: [PausedApplication] = []
    /// Bundle ID всех включённых приложений (для связи с ApplicationMonitor)
    @Published var enabledBundleIds: [String] = []

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let enabledApps = "ru.korenskoy.RecessEyes.pausedApps"
        static let manualApps  = "ru.korenskoy.RecessEyes.manualApps"
    }

    // MARK: - Initialization

    init() {
        // Быстрый путь: enabled IDs из UserDefaults (сразу, без сканирования диска)
        let saved = UserDefaults.standard.stringArray(forKey: Keys.enabledApps) ?? []
        enabledBundleIds = saved

        // Список приложений загружаем в фоне (для UI настроек)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadAppsFromDisk()
        }
    }

    // MARK: - Public Methods

    func addApp(bundleId: String, displayName: String, url: URL) {
        if let index = installedApps.firstIndex(where: { $0.bundleId == bundleId }) {
            // Уже есть в списке — просто включить
            installedApps[index].isEnabled = true
        } else {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let app = PausedApplication(bundleId: bundleId, displayName: displayName, isEnabled: true, icon: icon)
            let insertIndex = installedApps.firstIndex {
                $0.displayName.localizedCaseInsensitiveCompare(displayName) == .orderedDescending
            } ?? installedApps.endIndex
            installedApps.insert(app, at: insertIndex)

            // Запомнить как вручную добавленное
            var manual = savedManualApps
            manual.insert(bundleId)
            saveManualApps(manual)
        }
        saveEnabledIds()
        publishEnabledIds()
    }

    func removeApp(bundleId: String) {
        installedApps.removeAll { $0.bundleId == bundleId }

        var manual = savedManualApps
        manual.remove(bundleId)
        saveManualApps(manual)

        saveEnabledIds()
        publishEnabledIds()
    }

    func removeApp(_ app: PausedApplication) {
        removeApp(bundleId: app.bundleId)
    }

    func toggleApp(_ app: PausedApplication, enabled: Bool) {
        if let index = installedApps.firstIndex(where: { $0.bundleId == app.bundleId }) {
            installedApps[index].isEnabled = enabled
        }
        saveEnabledIds()
        publishEnabledIds()
    }

    // MARK: - Private

    private var savedManualApps: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Keys.manualApps) ?? [])
    }

    private func saveManualApps(_ apps: Set<String>) {
        UserDefaults.standard.set(Array(apps), forKey: Keys.manualApps)
    }

    private func saveEnabledIds() {
        let ids = installedApps.filter { $0.isEnabled }.map { $0.bundleId }
        UserDefaults.standard.set(ids, forKey: Keys.enabledApps)
    }

    private func publishEnabledIds() {
        enabledBundleIds = installedApps.filter { $0.isEnabled }.map { $0.bundleId }
    }

    private func loadAppsFromDisk() {
        let ud = UserDefaults.standard
        let enabledIds = Set(ud.stringArray(forKey: Keys.enabledApps) ?? [])
        let manualIds  = Set(ud.stringArray(forKey: Keys.manualApps) ?? [])

        var apps: [PausedApplication] = []
        let searchPaths = ["/Applications", "/System/Applications"]

        for path in searchPaths {
            let url = URL(fileURLWithPath: path)
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let appURL as URL in enumerator {
                guard let values = try? appURL.resourceValues(forKeys: [.isApplicationKey]),
                      values.isApplication == true,
                      let bundle = Bundle(url: appURL),
                      let bundleId = bundle.bundleIdentifier else { continue }

                guard !apps.contains(where: { $0.bundleId == bundleId }) else { continue }

                let displayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.infoDictionary?["CFBundleName"] as? String
                    ?? appURL.deletingPathExtension().lastPathComponent

                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                let isEnabled = enabledIds.contains(bundleId)
                apps.append(PausedApplication(bundleId: bundleId, displayName: displayName, isEnabled: isEnabled, icon: icon))
            }
        }

        // Вручную добавленные приложения, которых нет в стандартных папках
        for bundleId in manualIds where !apps.contains(where: { $0.bundleId == bundleId }) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let b = Bundle(url: appURL)
                let displayName = b?.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? b?.infoDictionary?["CFBundleName"] as? String
                    ?? appURL.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                let isEnabled = enabledIds.contains(bundleId)
                apps.append(PausedApplication(bundleId: bundleId, displayName: displayName, isEnabled: isEnabled, icon: icon))
            }
        }

        let sorted = apps.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        DispatchQueue.main.async { [weak self] in
            self?.installedApps = sorted
            self?.publishEnabledIds()
        }
    }
}
