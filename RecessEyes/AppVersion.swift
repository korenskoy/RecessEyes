//
//  AppVersion.swift
//  RecessEyes
//
//  Wrapper around Bundle for version info.
//  Source of truth for both values: RecessEyes/Version.xcconfig
//

import Foundation

enum AppVersion {
    /// CFBundleShortVersionString (MARKETING_VERSION) — e.g. "1.1"
    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// CFBundleVersion (CURRENT_PROJECT_VERSION) — e.g. "37"
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// Composed display string, e.g. "1.1 (37)"
    static var displayString: String {
        "\(marketing) (\(build))"
    }
}
