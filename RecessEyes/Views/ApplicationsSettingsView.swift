//
//  ApplicationsSettingsView.swift
//  RecessEyes
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ApplicationsSettingsView: View {
    @ObservedObject var pausedAppsManager: PausedAppsManager
    @State private var searchText: String = ""

    private var filtered: [PausedApplication] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let base = pausedAppsManager.installedApps
        let matched = q.isEmpty ? base : base.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.bundleId.lowercased().contains(q)
        }
        // Enabled first, then alphabetical within each group
        return matched.sorted { a, b in
            if a.isEnabled != b.isEnabled { return a.isEnabled }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private var pausedCount: Int {
        pausedAppsManager.installedApps.filter { $0.isEnabled }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Heading + subheading
                VStack(alignment: .leading, spacing: 4) {
                    Text("apps.heading")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.14)
                        .foregroundColor(DS.ink)
                    Text("apps.subheading")
                        .font(.system(size: 12))
                        .foregroundColor(DS.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 460, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Apps card
                VStack(spacing: 0) {
                    // Header
                    appsHeader

                    // Empty state or rows
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { app in
                            VStack(spacing: 0) {
                                AppRow(app: app) { enabled in
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        pausedAppsManager.toggleApp(app, enabled: enabled)
                                    }
                                }
                                if app.id != filtered.last?.id {
                                    Rectangle()
                                        .fill(DS.line)
                                        .frame(height: 1)
                                        .padding(.leading, 50)
                                }
                            }
                            .transition(.opacity)
                        }
                    }

                    // Footer
                    appsFooter
                }
                .background(DS.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .frame(minHeight: 580)
    }

    private var appsHeader: some View {
        HStack(spacing: 10) {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("apps.count", comment: ""),
                pausedAppsManager.installedApps.count.localizedDigits(),
                pausedCount.localizedDigits()
            ))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundColor(DS.ink2)

            Spacer()

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.muted)
                TextField("apps.search.placeholder", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundColor(DS.ink)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
            )
            .frame(maxWidth: 220)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedWhite: 0.985, alpha: 1)),
                    Color(nsColor: NSColor(calibratedWhite: 0.97, alpha: 1))
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.line).frame(height: 1)
        }
    }

    private var appsFooter: some View {
        HStack {
            Text("apps.footer")
                .font(.system(size: 11.5))
                .foregroundColor(DS.muted)
            Spacer()
            HStack(spacing: 0) {
                IconActionButton(systemName: "plus", isLeft: true) {
                    showAddAppPanel()
                }
                IconActionButton(systemName: "minus", isLeft: false) {
                    // Optional: remove last selected; for now no-op
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedWhite: 0.97, alpha: 1)),
                    Color(nsColor: NSColor(calibratedWhite: 0.955, alpha: 1))
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(DS.line).frame(height: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "app.dashed")
                .font(.system(size: 30))
                .foregroundColor(DS.muted2)
            Text("apps.empty")
                .font(.system(size: 12.5))
                .foregroundColor(DS.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func showAddAppPanel() {
        let panel = NSOpenPanel()
        panel.title = "Add Application"
        panel.allowedContentTypes = [UTType.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let bundle = Bundle(url: url)
            let bundleId = bundle?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
            let displayName = (bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle?.infoDictionary?["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
            DispatchQueue.main.async {
                pausedAppsManager.addApp(bundleId: bundleId, displayName: displayName, url: url)
            }
        }
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: PausedApplication
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App icon (NSImage from NSWorkspace)
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                } else {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(DS.muted.opacity(0.25))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(initials(for: app.displayName))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            }

            // Name + sub
            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(DS.ink)
                    .lineLimit(1)
                Text(app.bundleId)
                    .font(.system(size: 11))
                    .foregroundColor(DS.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Badge
            Text(app.isEnabled ? "apps.badge.pauses" : "apps.badge.ignored")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(app.isEnabled ? DS.accent : DS.ink2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(app.isEnabled ? DS.accentSoft : Color(nsColor: NSColor(calibratedWhite: 0.94, alpha: 1)))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                )

            // Toggle
            MacToggle(isOn: Binding(
                get: { app.isEnabled },
                set: { onToggle($0) }
            ))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func initials(for name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        return words.map { String($0.first ?? Character(" ")) }.joined()
    }
}

// MARK: - Icon action button (footer + and - buttons)

private struct IconActionButton: View {
    let systemName: String
    let isLeft: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DS.ink2)
                .frame(width: 26, height: 22)
                .background(
                    LinearGradient(
                        colors: [Color.white, Color(nsColor: NSColor(calibratedWhite: 0.97, alpha: 1))],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(corners: isLeft ? [.topLeft, .bottomLeft] : [.topRight, .bottomRight], radius: 5)
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: .init(
                        topLeading: isLeft ? 5 : 0,
                        bottomLeading: isLeft ? 5 : 0,
                        bottomTrailing: isLeft ? 0 : 5,
                        topTrailing: isLeft ? 0 : 5
                    ))
                    .strokeBorder(Color.black.opacity(0.14), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// Helper for one-side rounded corners on macOS
private extension View {
    func clipShape(corners: NSRectCorner, radius: CGFloat) -> some View {
        self.clipShape(UnevenRoundedRectangle(cornerRadii: .init(
            topLeading: corners.contains(.topLeft) ? radius : 0,
            bottomLeading: corners.contains(.bottomLeft) ? radius : 0,
            bottomTrailing: corners.contains(.bottomRight) ? radius : 0,
            topTrailing: corners.contains(.topRight) ? radius : 0
        )))
    }
}

private struct NSRectCorner: OptionSet {
    let rawValue: Int
    static let topLeft     = NSRectCorner(rawValue: 1 << 0)
    static let topRight    = NSRectCorner(rawValue: 1 << 1)
    static let bottomLeft  = NSRectCorner(rawValue: 1 << 2)
    static let bottomRight = NSRectCorner(rawValue: 1 << 3)
}
