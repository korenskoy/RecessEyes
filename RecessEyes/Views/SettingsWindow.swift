//
//  SettingsWindow.swift
//  RecessEyes
//

import SwiftUI
import AppKit

struct SettingsWindow: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var pausedAppsManager: PausedAppsManager
    @ObservedObject var timerManager: TimerManager
    var timerViewModel: TimerViewModel  // @Observable

    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: Hashable { case general, applications }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (system titlebar with title + pill is rendered by the NSWindow above)
            tabbar
                .background(
                    LinearGradient(
                        colors: [
                            Color(nsColor: NSColor(calibratedWhite: 0.945, alpha: 1)),
                            Color(nsColor: NSColor(calibratedWhite: 0.965, alpha: 1))
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(alignment: .bottom) {
                    Rectangle().fill(DS.line).frame(height: 1)
                }

            // Body
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(
                        appSettings: appSettings,
                        timerManager: timerManager,
                        timerViewModel: timerViewModel
                    )
                case .applications:
                    ApplicationsSettingsView(pausedAppsManager: pausedAppsManager)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(nsColor: NSColor(calibratedWhite: 0.985, alpha: 1)),
                        Color(nsColor: NSColor(calibratedWhite: 0.97, alpha: 1))
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        .frame(width: 720)
    }

    private var tabbar: some View {
        HStack {
            Spacer()
            SegmentedTab(
                selection: $selectedTab,
                options: [
                    (.general, "settings.tab.general"),
                    (.applications, "settings.tab.applications")
                ]
            )
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

