//
//  BreakOverlayView.swift
//  RecessEyes
//

import SwiftUI

struct BreakOverlayView: View {
    let getTimeRemaining: () -> Int
    let getTotalDuration: () -> Int
    let isExpired: () -> Bool
    let tipIndex: Int
    let onSkip: () -> Void
    let onLockScreen: () -> Void

    @State private var seconds: Int = 0
    @State private var total: Int = 20
    @State private var expired: Bool = false
    @State private var colonOn: Bool = true
    @State private var refreshTimer: Timer?
    @State private var blinkTimer: Timer?

    static let tipCount = 5

    // Scale curve: 1.0 at ~900px-tall screen; clamped so tiny windows stay
    // readable and huge displays don't get cartoon-sized elements.
    private static let baseHeight: CGFloat = 900
    private static let minScale: CGFloat = 0.7
    private static let maxScale: CGFloat = 1.5

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(total - seconds) / Double(total)
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let scale = max(Self.minScale, min(H / Self.baseHeight, Self.maxScale))

            let timerBlockHeight: CGFloat = 150 * scale
            let gapAroundTimer: CGFloat = 56 * scale

            ZStack {
                Color(white: 0.10).opacity(0.45)
                    .frame(width: W, height: H)

                // Symmetric three-zone layout: top zone and bottom zone share
                // the remaining height equally, so the timer stays centered
                // regardless of how long the tip text wraps.
                VStack(spacing: 0) {
                    titleSection(scale: scale)
                        .frame(maxWidth: min(W - 64, 540 * scale))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    Color.clear.frame(height: gapAroundTimer)

                    timerSection(scale: scale)
                        .frame(height: timerBlockHeight)

                    Color.clear.frame(height: gapAroundTimer)

                    bottomSection(scale: scale)
                        .frame(maxWidth: min(W - 64, 520 * scale))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(width: W, height: H)
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onAppear {
            updateState()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                updateState()
            }
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                colonOn.toggle()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate(); refreshTimer = nil
            blinkTimer?.invalidate(); blinkTimer = nil
        }
    }

    // MARK: - Sections

    private func titleSection(scale: CGFloat) -> some View {
        VStack(spacing: 14 * scale) {
            Text(expired ? "break.overlay.title.expired" : "break.overlay.title")
                .font(.system(size: 40 * scale, weight: .semibold))
                .tracking(-1.0)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(expired ? "break.overlay.expired" : "break.overlay.lede")
                .font(.system(size: 15 * scale))
                .foregroundColor(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 380 * scale)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func timerSection(scale: CGFloat) -> some View {
        ZStack {
            if expired {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 130 * scale, weight: .ultraLight))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 1)
            } else {
                VStack(spacing: 8 * scale) {
                    timerDisplay(scale: scale)
                    progressBar(scale: scale)
                }
            }
        }
    }

    private func bottomSection(scale: CGFloat) -> some View {
        VStack(spacing: 14 * scale) {
            tipPill(scale: scale)

            HStack(spacing: 10 * scale) {
                OverlayButton(
                    label: expired ? "break.overlay.done" : "break.overlay.skip",
                    icon: expired ? "checkmark" : "play.fill",
                    kbd: "esc",
                    primary: true,
                    action: onSkip
                )
                .keyboardShortcut(.cancelAction)
                OverlayButton(
                    label: "break.overlay.lock",
                    icon: "lock.fill",
                    kbd: "⌃⌘Q",
                    primary: false,
                    action: onLockScreen
                )
                .keyboardShortcut("q", modifiers: [.control, .command])
            }
        }
    }

    // MARK: - Timer / progress

    private func timerDisplay(scale: CGFloat) -> some View {
        let m = seconds / 60
        let s = seconds % 60
        return HStack(spacing: 0) {
            Text(m.localizedPadded(2))
            Text(verbatim: ":")
                .opacity(colonOn ? 1.0 : 0.35)
                .padding(.horizontal, 2 * scale)
            Text(s.localizedPadded(2))
        }
        .font(.system(size: 110 * scale, weight: .ultraLight).monospacedDigit())
        .tracking(-3)
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 1)
    }

    private func progressBar(scale: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(height: 4 * scale)
            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: geo.size.width * progress, height: 4 * scale)
            }
            .frame(height: 4 * scale)
        }
        .frame(maxWidth: 420 * scale)
    }

    // MARK: - Tip pill

    private func tipAttributed(scale: CGFloat) -> AttributedString {
        let titleKey = "break.overlay.tip.\(tipIndex).title"
        let bodyKey = "break.overlay.tip.\(tipIndex).body"
        let title = NSLocalizedString(titleKey, comment: "")
        let body = NSLocalizedString(bodyKey, comment: "")

        let fontSize = 12.5 * scale

        var titlePart = AttributedString(title)
        titlePart.font = .system(size: fontSize, weight: .semibold)
        titlePart.foregroundColor = .white

        var sep = AttributedString("  ·  ")
        sep.font = .system(size: fontSize)
        sep.foregroundColor = .white.opacity(0.85)

        var bodyPart = AttributedString(body)
        bodyPart.font = .system(size: fontSize)
        bodyPart.foregroundColor = .white.opacity(0.85)

        // For RTL languages (fa, ar) the reader scans right-to-left; emit
        // body + separator + title so the bold title still appears first
        // visually after BiDi reordering.
        let isRTL = Locale.current.language.characterDirection == .rightToLeft
        var result = AttributedString()
        if isRTL {
            result.append(bodyPart)
            result.append(sep)
            result.append(titlePart)
        } else {
            result.append(titlePart)
            result.append(sep)
            result.append(bodyPart)
        }
        return result
    }

    private func tipPill(scale: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 8 * scale) {
            Image(systemName: "sparkles")
                .font(.system(size: 12 * scale))
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 2 * scale)
            Text(tipAttributed(scale: scale))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: min(460 * scale, 560), alignment: .leading)
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 9 * scale)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    private func updateState() {
        expired = isExpired()
        if !expired {
            seconds = max(0, getTimeRemaining())
            total = max(seconds, getTotalDuration())
        }
    }
}

// MARK: - Overlay button (primary white / secondary translucent)

struct OverlayButton: View {
    let label: LocalizedStringKey
    let icon: String?
    let kbd: String?
    let primary: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                if let kbd = kbd {
                    Text(kbd)
                        .font(.system(size: 10.5).monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            primary ? Color.black.opacity(0.10)
                                    : Color.white.opacity(0.18)
                        )
                        .foregroundColor(
                            primary ? Color.black.opacity(0.6)
                                    : Color.white.opacity(0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .foregroundColor(primary ? Color(white: 0.20) : .white)
            .background(
                primary
                ? AnyShapeStyle(Color.white.opacity(hovered ? 0.96 : 1.0))
                : AnyShapeStyle(Color.white.opacity(hovered ? 0.18 : 0.12))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        primary ? Color.clear : Color.white.opacity(0.22),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: primary ? Color.black.opacity(0.4) : Color.clear,
                radius: primary ? 18 : 0,
                x: 0, y: primary ? 6 : 0
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
