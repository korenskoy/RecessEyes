//
//  MenuPopoverView.swift
//  RecessEyes
//

import SwiftUI
import AppKit

struct MenuPopoverView: View {
    @ObservedObject var timerManager: TimerManager
    var timerViewModel: TimerViewModel  // @Observable

    var onDoBreakNow: () -> Void
    var onTogglePause: () -> Void
    var onDisableUntilTomorrow: () -> Void
    var onSkipBreak: () -> Void
    var onSettings: () -> Void
    var onAbout: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top status card
            statusCard
                .padding(.bottom, 4)

            // Action items
            if timerManager.state == .onBreak || timerManager.state == .breakExpired {
                PopMenuItem(
                    label: "menu.skip_upcoming_break",
                    icon: "forward.fill",
                    kbd: nil,
                    action: onSkipBreak
                )
            } else {
                PopMenuItem(
                    label: "menu.do_break_now",
                    icon: "cup.and.saucer.fill",
                    kbd: "⌃⌥B",
                    action: onDoBreakNow
                )
            }
            PopMenuItem(
                label: timerManager.isPausedManually ? "menu.resume" : "menu.pause",
                icon: timerManager.isPausedManually ? "play.fill" : "pause.fill",
                kbd: "⌘P",
                action: onTogglePause
            )
            if timerViewModel.disabledUntilDate == nil {
                PopMenuItem(
                    label: "menu.disable_tomorrow",
                    icon: "moon.fill",
                    kbd: "⌘.",
                    action: onDisableUntilTomorrow
                )
            }

            menuDivider

            PopMenuItem(label: "menu.settings", icon: "gearshape.fill", kbd: "⌘,", action: onSettings)
            PopMenuItem(label: "menu.about", icon: "info.circle.fill", kbd: nil, action: onAbout)

            menuDivider

            PopMenuItem(label: "menu.quit", icon: "rectangle.portrait.and.arrow.right", kbd: "⌘Q", action: onQuit)
        }
        .padding(6)
        .frame(width: 300)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(DS.hairline)
            .frame(height: 1)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(headlineText)
                    .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                    .foregroundColor(DS.ink)
                Spacer()
                pill
            }

            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 4)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 999)
                        .fill(DS.accent)
                        .frame(width: geo.size.width * progress, height: 4)
                }
                .frame(height: 4)
            }

            Text("popover.card.subtext")
                .font(.system(size: 10.5))
                .foregroundColor(DS.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DS.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private var progress: Double {
        let total = timerManager.isWorkInterval
            ? timerManager.workIntervalSeconds
            : timerManager.breakIntervalSeconds
        guard total > 0 else { return 0 }
        let p = 1.0 - Double(timerManager.timeRemaining) / Double(total)
        return min(max(p, 0), 1)
    }

    private var headlineText: String {
        if timerViewModel.disabledUntilDate != nil {
            return String(localized: "popover.card.paused")
        }
        switch timerManager.state {
        case .onBreak, .breakExpired:
            return String.localizedStringWithFormat(
                NSLocalizedString("popover.card.on_break", comment: ""),
                timerManager.timeRemaining.localizedDigits()
            )
        case .working where timerManager.isPausedManually,
             .idle where timerManager.isPausedManually:
            return String(localized: "popover.card.paused")
        default:
            let t = timerManager.timeRemaining
            return String.localizedStringWithFormat(
                NSLocalizedString("popover.card.next_break", comment: ""),
                (t / 60).localizedDigits(),
                (t % 60).localizedDigits()
            )
        }
    }

    @ViewBuilder
    private var pill: some View {
        let (key, color): (LocalizedStringKey, Color) = {
            if timerViewModel.disabledUntilDate != nil { return ("popover.pill.off", DS.ink2) }
            switch timerManager.state {
            case .onBreak, .breakExpired: return ("popover.pill.break", DS.iconOrange)
            case .working where timerManager.isPausedManually,
                 .idle where timerManager.isPausedManually:
                return ("popover.pill.paused", DS.ink2)
            default: return ("popover.pill.focus", DS.accent)
            }
        }()

        Text(key)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .foregroundColor(.white)
            .tracking(0.1)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Pop menu item

struct PopMenuItem: View {
    let label: LocalizedStringKey
    let icon: String?
    let kbd: String?
    var muted: Bool = false
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(hovered ? .white : (muted ? DS.muted : DS.ink2))
                        .frame(width: 16, height: 16)
                } else {
                    Color.clear.frame(width: 16, height: 16)
                }

                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(hovered ? .white : (muted ? DS.muted : DS.ink))

                Spacer(minLength: 8)

                if let kbd = kbd {
                    Text(kbd)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundColor(hovered ? .white.opacity(0.85) : DS.muted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                hovered ? DS.accent : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .padding(.vertical, 1)
    }
}
