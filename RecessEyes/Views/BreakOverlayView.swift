//
//  BreakOverlayView.swift
//  RecessEyes
//

import SwiftUI

struct BreakOverlayView: View {
    let getTimeRemaining: () -> Int
    let getTotalDuration: () -> Int
    let isExpired: () -> Bool
    let onSkip: () -> Void
    let onLockScreen: () -> Void

    @State private var seconds: Int = 0
    @State private var total: Int = 20
    @State private var expired: Bool = false
    @State private var colonOn: Bool = true
    @State private var refreshTimer: Timer?
    @State private var blinkTimer: Timer?

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(total - seconds) / Double(total)
    }

    var body: some View {
        ZStack {
            // Dark tint over the NSVisualEffectView blur
            Color(white: 0.10).opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer()

                // Title
                Text(expired ? "break.overlay.title.expired" : "break.overlay.title")
                    .font(.system(size: 40, weight: .semibold))
                    .tracking(-1.0)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 96, alignment: .center)

                // Lede / expired message — fixed-height container so 1-line and
                // multi-line variants don't cause vertical layout shift.
                Text(expired ? "break.overlay.expired" : "break.overlay.lede")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 380, minHeight: 44, alignment: .center)

                // Giant timer / completion checkmark — fixed-height container
                // so layout doesn't shift when the break expires.
                ZStack {
                    if expired {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 130, weight: .ultraLight))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 1)
                    } else {
                        VStack(spacing: 8) {
                            timerDisplay
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                                    .frame(height: 4)
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color.white.opacity(0.85))
                                        .frame(width: geo.size.width * progress, height: 4)
                                }
                                .frame(height: 4)
                            }
                            .frame(maxWidth: 420)
                        }
                    }
                }
                .frame(height: 150)
                .padding(.top, 4)

                // Tip pill
                tipPill
                    .padding(.top, 4)

                // Buttons
                HStack(spacing: 10) {
                    // Primary: Skip / Done (white bg, dark text)
                    OverlayButton(
                        label: expired ? "break.overlay.done" : "break.overlay.skip",
                        icon: expired ? "checkmark" : "play.fill",
                        kbd: "esc",
                        primary: true,
                        action: onSkip
                    )
                    .keyboardShortcut(.cancelAction)
                    // Secondary: Lock screen
                    OverlayButton(
                        label: "break.overlay.lock",
                        icon: "lock.fill",
                        kbd: "⌃⌘Q",
                        primary: false,
                        action: onLockScreen
                    )
                    .keyboardShortcut("q", modifiers: [.control, .command])
                }
                .padding(.top, 14)

                Spacer()
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
        }
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

    // MARK: - Timer display

    private var timerDisplay: some View {
        let m = seconds / 60
        let s = seconds % 60
        return HStack(spacing: 0) {
            Text(m.localizedPadded(2))
            Text(verbatim: ":")
                .opacity(colonOn ? 1.0 : 0.35)
                .padding(.horizontal, 2)
            Text(s.localizedPadded(2))
        }
        .font(.system(size: 110, weight: .ultraLight).monospacedDigit())
        .tracking(-3)
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 1)
    }

    private var tipPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
            HStack(spacing: 4) {
                Text("break.overlay.tip.label")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(verbatim: "·")
                    .foregroundColor(.white.opacity(0.85))
                Text("break.overlay.tip.body")
                    .foregroundColor(.white.opacity(0.85))
            }
            .font(.system(size: 12.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
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
