//
//  LanguageManager.swift
//  RecessEyes
//

import Foundation
import AppKit

/// Manages app language override via AppleLanguages key.
/// Changes require app restart to take full effect.
enum LanguageManager {
    static let supportedCodes: [String] = ["en", "es", "ru", "az", "fa"]

    /// User-selected language code, or nil if following the system.
    static var currentOverride: String? {
        get {
            UserDefaults.standard.string(forKey: "ru.korenskoy.RecessEyes.languageOverride")
        }
        set {
            let ud = UserDefaults.standard
            if let code = newValue, !code.isEmpty {
                ud.set(code, forKey: "ru.korenskoy.RecessEyes.languageOverride")
                ud.set([code], forKey: "AppleLanguages")
            } else {
                ud.removeObject(forKey: "ru.korenskoy.RecessEyes.languageOverride")
                ud.removeObject(forKey: "AppleLanguages")
            }
        }
    }

    /// Restart the application to pick up the new language.
    static func restartApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }
}
