//
//  TimerViewModel.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import AppKit
import Foundation
import Combine
import UserNotifications

/// ViewModel для управления таймером
@Observable
class TimerViewModel {
    // MARK: - Observable Properties
    var timeRemaining: Int = 0
    var state: TimerState = .idle
    var isWorkInterval: Bool = true
    var isManuallyPaused: Bool = false

    // MARK: - Properties
    private let timerManager: TimerManager
    private let applicationMonitor: ApplicationMonitor
    private let overlayWindowManager: OverlayWindowManager
    private let appSettings: AppSettings
    private let inactivityMonitor: InactivityMonitor
    private let eyeDropsReminderManager: EyeDropsReminderManager

    /// Дата, до которой приложение отключено (nil = активно)
    var disabledUntilDate: Date?
    private var disableTimer: Timer?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        timerManager: TimerManager,
        applicationMonitor: ApplicationMonitor,
        overlayWindowManager: OverlayWindowManager,
        appSettings: AppSettings
    ) {
        self.timerManager = timerManager
        self.applicationMonitor = applicationMonitor
        self.overlayWindowManager = overlayWindowManager
        self.appSettings = appSettings
        self.inactivityMonitor = InactivityMonitor()
        self.eyeDropsReminderManager = EyeDropsReminderManager(intervalMinutes: appSettings.eyeDropsInterval)

        setupBindings()
        setupInactivityMonitor()
        setupEyeDropsReminder()
        setupScreenLockObserver()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Public Methods

    func startSession() {
        timerManager.start()
    }

    /// Переключить ручную паузу (из меню)
    func toggleManualPause() {
        if disabledUntilDate != nil {
            resumeFromDisable()
        } else {
            timerManager.toggleManualPause()
        }
    }

    /// Отключить до 6:00 следующего дня
    func disableUntilTomorrow() {
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var components = Calendar.current.dateComponents([.year, .month, .day], from: nextDay)
        components.hour = 6
        components.minute = 0
        components.second = 0
        let target = Calendar.current.date(from: components)!
        disabledUntilDate = target
        timerManager.pauseManually()

        disableTimer?.invalidate()
        disableTimer = Timer.scheduledTimer(withTimeInterval: target.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.resumeFromDisable()
            }
        }
    }

    /// Досрочно возобновить после «отключить до завтра»
    private func resumeFromDisable() {
        disableTimer?.invalidate()
        disableTimer = nil
        disabledUntilDate = nil
        timerManager.resumeManually()
    }

    func skipBreak() {
        timerManager.skip()
        overlayWindowManager.hideAllOverlays()
    }

    func skipUpcomingBreak() {
        cancelBreakWarningNotification()
        timerManager.skipUpcomingBreak()
    }

    func doBreakNow() {
        timerManager.doBreakNow()
    }

    func extendBreak() {
        timerManager.timeRemaining += 180  // +3 мин
    }

    func lockScreen() {
        // Process() и большинство DistributedNotification для loginwindow заблокированы
        // в sandboxed-приложениях. Приватная функция SACLockScreenImmediate из
        // login.framework работает в sandbox и блокирует экран немедленно.
        typealias SACLockScreenImmediateType = @convention(c) () -> Void
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/A/login"

        if let handle = dlopen(path, RTLD_LAZY) {
            defer { dlclose(handle) }
            if let sym = dlsym(handle, "SACLockScreenImmediate") {
                let lockFn = unsafeBitCast(sym, to: SACLockScreenImmediateType.self)
                lockFn()
                return
            }
        }

        // Fallback: попробовать активировать скринсейвер (сработает, если в системе
        // выставлено «требовать пароль сразу»).
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.apple.screensaver.forceactivate"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    // MARK: - Private: bindings

    private func setupBindings() {
        timerManager.$timeRemaining
            .sink { [weak self] in self?.timeRemaining = $0 }
            .store(in: &cancellables)

        timerManager.$state
            .sink { [weak self] in self?.state = $0 }
            .store(in: &cancellables)

        timerManager.$isWorkInterval
            .sink { [weak self] in self?.isWorkInterval = $0 }
            .store(in: &cancellables)

        timerManager.$isPausedManually
            .sink { [weak self] in self?.isManuallyPaused = $0 }
            .store(in: &cancellables)

        // Изменения настроек → обновить интервалы
        appSettings.$workInterval
            .combineLatest(appSettings.$breakInterval)
            .sink { [weak self] work, brk in
                self?.timerManager.updateIntervals(work: work, breakInterval: brk)
            }
            .store(in: &cancellables)

        // Изменения breakInterval → порог неактивности
        appSettings.$breakInterval
            .sink { [weak self] brk in
                self?.inactivityMonitor.threshold = TimeInterval(brk)
            }
            .store(in: &cancellables)

        // ApplicationMonitor → автоматическая пауза
        applicationMonitor.$shouldPause
            .sink { [weak self] shouldPause in
                if shouldPause {
                    self?.timerManager.pauseByApp()
                } else {
                    self?.timerManager.resumeByApp()
                }
            }
            .store(in: &cancellables)

        // TimerManager callbacks
        timerManager.onBreakStarted = { [weak self] in
            guard let self else { return }
            self.cancelBreakWarningNotification()
            self.overlayWindowManager.showBreakOverlay(
                getTimeRemaining: { self.timerManager.timeRemaining },
                getTotalDuration: { self.timerManager.breakIntervalSeconds }
            )
        }

        timerManager.onBreakEnding = { [weak self] in
            guard let self, self.appSettings.preBreakWarning else { return }
            self.postBreakWarningNotification()
        }

        timerManager.onBreakExpired = { [weak self] in
            guard let self else { return }
            // Оверлей остаётся — переходим в режим ожидания закрытия вручную
            self.overlayWindowManager.markBreakExpired()
            // Звук играем только когда таймер перерыва реально досчитал до конца.
            // Через ChimePlayer добавляем +12 дБ усиления — пользователь к этому
            // моменту уже отошёл от компьютера и должен услышать.
            if self.appSettings.breakChime,
               let url = Bundle.main.url(forResource: "break_end", withExtension: "mp3") {
                ChimePlayer.shared.play(url: url)
            }
        }

        timerManager.onWorkStarted = { [weak self] in
            self?.inactivityMonitor.resetFiredFlag()
        }

        // OverlayWindowManager callbacks
        overlayWindowManager.onSkip = { [weak self] in
            self?.timerManager.skip()
        }

        overlayWindowManager.onLockScreen = { [weak self] in
            self?.lockScreen()
        }
    }

    // MARK: - Private: notifications

    private func postBreakWarningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time for a break"
        content.body = "Focus on a distant point"
        content.sound = .default
        content.categoryIdentifier = "BREAK_WARNING"

        let request = UNNotificationRequest(identifier: "break_warning", content: content, trigger: nil)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["break_warning"])
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelBreakWarningNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["break_warning"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["break_warning"])
    }

    private func setupScreenLockObserver() {
        // Если экран блокируется во время перерыва (через нашу кнопку Lock,
        // ⌃⌘Q, hot corner и т. п.) — завершаем перерыв, чтобы при разблокировке
        // пользователь оказался уже в новом рабочем цикле.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.state == .onBreak || self.state == .breakExpired {
                    self.skipBreak()
                }
            }
        }
    }

    private func setupEyeDropsReminder() {
        if appSettings.eyeDropsEnabled {
            eyeDropsReminderManager.startMonitoring()
        }

        appSettings.$eyeDropsEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.eyeDropsReminderManager.startMonitoring()
                } else {
                    self?.eyeDropsReminderManager.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        appSettings.$eyeDropsInterval
            .dropFirst()
            .sink { [weak self] minutes in
                self?.eyeDropsReminderManager.updateInterval(minutes: minutes)
            }
            .store(in: &cancellables)
    }

    private func setupInactivityMonitor() {
        inactivityMonitor.threshold = TimeInterval(appSettings.breakInterval)

        inactivityMonitor.onInactivity = { [weak self] in
            DispatchQueue.main.async {
                self?.timerManager.handleInactivity()
            }
        }

        inactivityMonitor.startMonitoring()
    }
}
