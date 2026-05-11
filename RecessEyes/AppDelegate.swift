//
//  AppDelegate.swift
//  RecessEyes
//

import AppKit
import SwiftUI
import Combine
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    // MARK: - Properties
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var aboutWindow: NSWindow?
    var menuPopover: NSPopover?

    private var timerManager: TimerManager!
    private var applicationMonitor: ApplicationMonitor!
    private var overlayWindowManager: OverlayWindowManager!
    private var sleepWakeMonitor: SleepWakeMonitor!

    private var appSettings: AppSettings!
    private var pausedAppsManager: PausedAppsManager!
    private var timerViewModel: TimerViewModel!

    private var cancellables = Set<AnyCancellable>()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        setupNotifications()

        appSettings = AppSettings()

        timerManager = TimerManager()
        applicationMonitor = ApplicationMonitor()
        overlayWindowManager = OverlayWindowManager()
        sleepWakeMonitor = SleepWakeMonitor()

        pausedAppsManager = PausedAppsManager()

        applicationMonitor.setUpPausedApps(pausedAppsManager.enabledBundleIds)
        pausedAppsManager.$enabledBundleIds
            .sink { [weak self] ids in
                self?.applicationMonitor.setUpPausedApps(ids)
                self?.appSettings.pausedApps = ids
            }
            .store(in: &cancellables)

        timerViewModel = TimerViewModel(
            timerManager: timerManager,
            applicationMonitor: applicationMonitor,
            overlayWindowManager: overlayWindowManager,
            appSettings: appSettings
        )

        sleepWakeMonitor.onSleepWake = { [weak self] duration in
            self?.timerManager.handleSleepWake(sleepDuration: duration)
        }

        setupStatusBar()

        applicationMonitor.startMonitoring()
        sleepWakeMonitor.startMonitoring()

        timerManager.start()

        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        applicationMonitor.stopMonitoring()
        sleepWakeMonitor.stopMonitoring()
    }

    // MARK: - Setup

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let skipAction = UNNotificationAction(identifier: "SKIP", title: "Skip", options: [])
        let extendAction = UNNotificationAction(identifier: "EXTEND", title: "+3 min", options: [])
        let breakWarningCategory = UNNotificationCategory(
            identifier: "BREAK_WARNING",
            actions: [skipAction, extendAction],
            intentIdentifiers: []
        )

        let eyeDropsCategory = UNNotificationCategory(
            identifier: "EYE_DROPS",
            actions: [],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([breakWarningCategory, eyeDropsCategory])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)

            switch response.actionIdentifier {
            case "SKIP":
                self.timerViewModel.skipUpcomingBreak()
            case "EXTEND":
                self.timerViewModel.extendBreak()
            default:
                break
            }
        }
        completionHandler()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.action = #selector(toggleMenuPopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        updateStatusBarButton()

        timerManager.$timeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusBarButton() }
            .store(in: &cancellables)

        timerManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusBarButton() }
            .store(in: &cancellables)

        timerManager.$isPausedManually
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusBarButton() }
            .store(in: &cancellables)

        appSettings.$launchAtLogin
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateStatusBarButton() }
            }
            .store(in: &cancellables)
    }

    private func updateStatusBarButton() {
        guard let button = statusItem?.button else { return }

        let timeString = localizedTimeMMSS(timerManager.timeRemaining)

        let iconName = timerManager.isPausedManually ? "eye.slash" : "eye"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        button.imagePosition = .imageLeft

        let monoFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.attributedTitle = NSAttributedString(string: timeString, attributes: [.font: monoFont])
    }

    @objc private func toggleMenuPopover() {
        guard let button = statusItem?.button else { return }

        if let popover = menuPopover, popover.isShown {
            popover.performClose(nil)
            return
        }

        if menuPopover == nil {
            let content = MenuPopoverView(
                timerManager: timerManager,
                timerViewModel: timerViewModel,
                onDoBreakNow: { [weak self] in
                    self?.menuPopover?.performClose(nil)
                    self?.timerViewModel.doBreakNow()
                },
                onTogglePause: { [weak self] in
                    self?.menuPopover?.performClose(nil)
                    self?.timerViewModel.toggleManualPause()
                },
                onDisableUntilTomorrow: { [weak self] in
                    self?.menuPopover?.performClose(nil)
                    self?.timerViewModel.disableUntilTomorrow()
                },
                onSkipBreak: { [weak self] in
                    self?.menuPopover?.performClose(nil)
                    self?.timerViewModel.skipBreak()
                },
                onSettings: { [weak self] in
                    self?.menuPopover?.performClose(nil)
                    self?.openSettings()
                },
                onAbout: { [weak self] in
                    self?.menuPopover?.performClose(nil)
                    self?.openAbout()
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                }
            )

            let popover = NSPopover()
            popover.contentViewController = NSHostingController(
                rootView: content.localizedLayoutDirection()
            )
            popover.behavior = .transient
            popover.animates = true
            menuPopover = popover
        }

        menuPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - Windows

    private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsWindow(
                appSettings: appSettings,
                pausedAppsManager: pausedAppsManager,
                timerManager: timerManager,
                timerViewModel: timerViewModel
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 760),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = String(localized: "settings.window.title")
            window.titleVisibility = .visible
            window.setFrameAutosaveName("SettingsWindow")
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(
                rootView: settingsView.localizedLayoutDirection()
            )
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openAbout() {
        if aboutWindow == nil {
            aboutWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            aboutWindow?.center()
            aboutWindow?.title = "About RecessEyes"
            aboutWindow?.isReleasedWhenClosed = false
            aboutWindow?.contentViewController = NSHostingController(
                rootView: AboutView().localizedLayoutDirection()
            )
        }

        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
