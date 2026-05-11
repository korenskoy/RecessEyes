//
//  Int+Localized.swift
//  RecessEyes
//
//  Locale-aware digit formatting. In Persian, digits become ۰۱۲۳۴۵۶۷۸۹.
//

import Foundation
import SwiftUI

// MARK: - App-effective locale

extension Locale {
    /// The locale that matches the app's currently active UI language
    /// (respects `AppleLanguages` override set via LanguageManager).
    /// Use this instead of `.autoupdatingCurrent` for any formatting tied to UI language.
    static var appEffective: Locale {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: lang)
    }
}

// MARK: - Layout direction

extension View {
    /// Applies the layout direction matching the app's effective locale
    /// (respects `AppleLanguages` override set via LanguageManager).
    func localizedLayoutDirection() -> some View {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        let dir = Locale.Language(identifier: lang).characterDirection
        return self.environment(
            \.layoutDirection,
            dir == .rightToLeft ? .rightToLeft : .leftToRight
        )
    }
}

extension Int {
    /// App-effective-locale digit string. No grouping separator.
    /// 12 → "12" (en) / "۱۲" (fa) / "12" (ru)
    func localizedDigits() -> String {
        let f = NumberFormatter()
        f.locale = .appEffective
        f.numberStyle = .none
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Locale-aware padded digit string.
    /// 5.localizedPadded(2) → "05" (en) / "۰۵" (fa)
    func localizedPadded(_ width: Int) -> String {
        let s = self.localizedDigits()
        guard s.count < width else { return s }
        let zero = 0.localizedDigits()
        return String(repeating: zero, count: width - s.count) + s
    }
}

/// MM:SS style time string in current locale's digits (both fields zero-padded to 2 chars).
/// Stable width up to 99 minutes — prevents the menubar / countdown text from jittering.
func localizedTimeMMSS(_ totalSeconds: Int) -> String {
    let t = max(0, totalSeconds)
    let m = t / 60
    let s = t % 60
    return "\(m.localizedPadded(2)):\(s.localizedPadded(2))"
}

/// Two-digit minute string (or 00 if < 0)
func localizedDigitsPadded(_ value: Int, width: Int = 2) -> String {
    return max(0, value).localizedPadded(width)
}
