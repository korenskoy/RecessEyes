//
//  SettingsComponents.swift
//  RecessEyes
//

import SwiftUI
import AppKit

// MARK: - Design tokens (mockup palette)

enum DS {
    // Colors
    static let surface       = Color(nsColor: NSColor.white)
    static let surfaceInset  = Color(nsColor: NSColor(calibratedRed: 0.965, green: 0.965, blue: 0.97, alpha: 1))
    static let line          = Color(nsColor: NSColor(calibratedWhite: 0.86, alpha: 0.9))
    static let ink           = Color(nsColor: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 1))
    static let ink2          = Color(nsColor: NSColor(calibratedRed: 0.36, green: 0.36, blue: 0.38, alpha: 1))
    static let muted         = Color(nsColor: NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.58, alpha: 1))
    static let muted2        = Color(nsColor: NSColor(calibratedRed: 0.66, green: 0.66, blue: 0.70, alpha: 1))
    static let accent        = Color(nsColor: NSColor(calibratedRed: 0.18, green: 0.47, blue: 0.97, alpha: 1))
    static let accentSoft    = Color(nsColor: NSColor(calibratedRed: 0.18, green: 0.47, blue: 0.97, alpha: 0.12))

    // Icon tones
    static let iconBlue     = Color(nsColor: NSColor(calibratedRed: 0.18, green: 0.47, blue: 0.97, alpha: 1))
    static let iconOrange   = Color(nsColor: NSColor(calibratedRed: 0.95, green: 0.58, blue: 0.10, alpha: 1))
    static let iconRed      = Color(nsColor: NSColor(calibratedRed: 0.92, green: 0.30, blue: 0.22, alpha: 1))
    static let iconGreen    = Color(nsColor: NSColor(calibratedRed: 0.20, green: 0.74, blue: 0.45, alpha: 1))
    static let iconPurple   = Color(nsColor: NSColor(calibratedRed: 0.62, green: 0.32, blue: 0.85, alpha: 1))
    static let iconGraphite = Color(nsColor: NSColor(calibratedRed: 0.36, green: 0.37, blue: 0.40, alpha: 1))
}

// MARK: - Icon Tile (22×22 colored square with white SF Symbol)

struct IconTile: View {
    let systemName: String
    let tone: Color
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(tone)
            Image(systemName: systemName)
                .font(.system(size: size * 0.6, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Group Card (white, rounded, hairline border)

struct GroupCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Group Label (uppercase muted, "TIMER")

struct GroupLabel: View {
    let key: LocalizedStringKey

    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DS.muted)
            .textCase(.uppercase)
            .tracking(0.04 * 11)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Row divider (1px, indented past icon)

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.line)
            .frame(height: 1)
            .padding(.leading, 48)
    }
}

// MARK: - Settings Row (icon + label/sub + control)

struct SettingsRow<Control: View>: View {
    let icon: String
    let tone: Color
    let title: LocalizedStringKey
    let sub: LocalizedStringKey?
    @ViewBuilder let control: () -> Control

    init(
        icon: String,
        tone: Color,
        title: LocalizedStringKey,
        sub: LocalizedStringKey? = nil,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.icon = icon
        self.tone = tone
        self.title = title
        self.sub = sub
        self.control = control
    }

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemName: icon, tone: tone)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(DS.ink)
                if let sub {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(DS.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

// MARK: - Mac-style Toggle (36×22, accent on)

struct MacToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.regular)
            .tint(DS.accent)
    }
}

// MARK: - Chevron Stepper (value + unit + stacked chevrons)

struct ChevronStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: LocalizedStringKey

    init(value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1, unit: LocalizedStringKey) {
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                Text(self.value.localizedDigits())
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundColor(DS.ink)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(DS.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minWidth: 64, alignment: .trailing)

            Rectangle()
                .fill(Color.black.opacity(0.10))
                .frame(width: 0.5)

            VStack(spacing: 0) {
                StepperButton(symbol: "chevron.up") {
                    let newVal = value + step
                    if newVal <= range.upperBound { value = newVal }
                }
                Rectangle()
                    .fill(Color.black.opacity(0.10))
                    .frame(height: 0.5)
                StepperButton(symbol: "chevron.down") {
                    let newVal = value - step
                    if newVal >= range.lowerBound { value = newVal }
                }
            }
            .frame(width: 18)
        }
        .background(DS.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
        )
    }
}

private struct StepperButton: View {
    let symbol: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(DS.ink2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(hovered ? Color.black.opacity(0.04) : Color.white)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .frame(height: 12)
    }
}

// MARK: - Pop-up Button (used for language picker)

struct PopupButton<Item: Hashable, ItemLabel: View>: View {
    @Binding var selection: Item
    let items: [Item]
    @ViewBuilder let label: (Item) -> ItemLabel

    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    label(item)
                }
            }
        } label: {
            HStack(spacing: 4) {
                label(selection)
                    .foregroundColor(DS.ink)
                    .font(.system(size: 13))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(DS.ink2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color.white, Color(nsColor: NSColor(calibratedWhite: 0.97, alpha: 1))],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color.black.opacity(0.14), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - Segmented Tab (for window tabbar)

struct SegmentedTab<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, LocalizedStringKey)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let selected = selection == option.0
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) { selection = option.0 }
                } label: {
                    Text(option.1)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selected ? DS.ink : DS.ink2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(
                            Group {
                                if selected {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.10), radius: 1, x: 0, y: 1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor(calibratedWhite: 0.91, alpha: 1)))
        )
    }
}

// MARK: - Status Hero (ring + title/sub + wall clock)

struct StatusHero: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var appSettings: AppSettings
    var disabledUntilDate: Date?

    private var progress: Double {
        let total = timerManager.isWorkInterval
            ? timerManager.workIntervalSeconds
            : timerManager.breakIntervalSeconds
        guard total > 0 else { return 0 }
        let p = 1.0 - Double(timerManager.timeRemaining) / Double(total)
        return min(max(p, 0), 1)
    }

    private var ringText: String {
        return localizedTimeMMSS(timerManager.timeRemaining)
    }

    var body: some View {
        HStack(spacing: 16) {
            ProgressRing(progress: progress, text: ringText)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                headlineLine
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(DS.ink)
                Text("hero.sub")
                    .font(.system(size: 11.5))
                    .foregroundColor(DS.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(predictedTime)
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundColor(DS.ink)
                    .tracking(-0.4)
                Text(predictedDate)
                    .font(.system(size: 11))
                    .foregroundColor(DS.muted)
            }
        }
        .padding(16)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var headlineLine: some View {
        if disabledUntilDate != nil {
            Text("hero.title.disabled")
        } else {
            switch timerManager.state {
            case .onBreak, .breakExpired:
                Text("hero.title.break")
            case .working where timerManager.isPausedManually,
                 .idle where timerManager.isPausedManually:
                Text("hero.title.paused")
            default:
                let t = timerManager.timeRemaining
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("hero.title.working", comment: ""),
                    (t / 60).localizedDigits(),
                    (t % 60).localizedDigits()
                ))
            }
        }
    }

    /// Time when the next break will start (Date() at render + remaining work seconds).
    /// Computed at render time so SwiftUI's re-render on `timeRemaining` change keeps it stable
    /// (no separate wall-clock timer drifting out of phase with the countdown).
    private var predictedBreakDate: Date {
        let now = Date()
        if disabledUntilDate != nil { return now }
        guard timerManager.isWorkInterval, !timerManager.isPausedManually else { return now }
        return now.addingTimeInterval(TimeInterval(timerManager.timeRemaining))
    }

    private var predictedTime: String {
        let f = DateFormatter()
        f.locale = .appEffective
        f.dateFormat = "HH:mm"
        return f.string(from: predictedBreakDate)
    }

    private var predictedDate: String {
        let f = DateFormatter()
        f.locale = .appEffective
        f.setLocalizedDateFormatFromTemplate("EEE MMM d")
        let s = f.string(from: predictedBreakDate)
        // Mockup uses "Wed · Sept 17" — replace any comma with bullet
        return s.replacingOccurrences(of: ",", with: " ·")
    }
}

// MARK: - Progress Ring (conic accent, white inner, monospaced text)

struct ProgressRing: View {
    let progress: Double  // 0…1
    let text: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: DS.accent, location: 0),
                            .init(color: DS.accent, location: progress),
                            .init(color: Color(nsColor: NSColor(calibratedWhite: 0.90, alpha: 1)), location: progress),
                            .init(color: Color(nsColor: NSColor(calibratedWhite: 0.90, alpha: 1)), location: 1)
                        ]),
                        center: .center
                    )
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(DS.surface)
                .padding(5)

            Text(text)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(DS.ink)
                .tracking(-0.1)
        }
    }
}

// MARK: - Why-these-defaults explainer row (custom layout, info icon + body with [20] pills)

struct ExplainerRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(systemName: "info.circle.fill", tone: DS.iconBlue)

            VStack(alignment: .leading, spacing: 6) {
                Text("settings.explainer.title")
                    .font(.system(size: 13))
                    .foregroundColor(DS.ink)

                HStack(spacing: 3) {
                    NumPill(20)
                    NumPill(20)
                    NumPill(20)
                }

                Text(.init(String(localized: "settings.explainer.body")))
                    .font(.system(size: 11))
                    .foregroundColor(DS.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

private struct NumPill: View {
    let value: Int
    init(_ value: Int) { self.value = value }

    var body: some View {
        Text(value.localizedDigits())
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .foregroundColor(DS.accent)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .frame(minWidth: 20)
            .background(DS.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
