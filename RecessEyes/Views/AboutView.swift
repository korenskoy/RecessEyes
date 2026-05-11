//
//  AboutView.swift
//  RecessEyes
//

import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            appIcon
                .frame(width: 96, height: 96)
                .padding(.top, 28)

            Text(verbatim: "RecessEyes")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(DS.ink)

            Text(String(format: NSLocalizedString("about.version", comment: ""), AppVersion.displayString))
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundColor(DS.muted)
                .padding(.top, -6)

            Text("about.tagline")
                .font(.system(size: 13))
                .foregroundColor(DS.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 6)

            Spacer(minLength: 8)

            Text(verbatim: "© 2026 Anton Korenskoy")
                .font(.system(size: 11))
                .foregroundColor(DS.muted)
                .padding(.bottom, 18)
        }
        .frame(width: 320, height: 340)
        .background(
            LinearGradient(
                colors: [DS.windowTop, DS.windowBottom],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [DS.accent, DS.accent.opacity(0.78)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Image(systemName: "eye.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }
            .shadow(color: DS.accent.opacity(0.3), radius: 12, x: 0, y: 6)
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
