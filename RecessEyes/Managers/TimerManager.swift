//
//  TimerManager.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation
import Combine
import os.log

/// Менеджер таймера, управляющий отсчётом и состояниями
class TimerManager: NSObject, ObservableObject {
    private static let log = Logger(subsystem: "ru.korenskoy.RecessEyes", category: "Timer")

    // MARK: - Published Properties
    @Published var timeRemaining: Int = 0
    @Published var state: TimerState = .idle
    @Published var isWorkInterval: Bool = true
    @Published var isPausedManually: Bool = false

    // MARK: - Properties
    var workIntervalSeconds: Int = 2700  // 45 мин
    var breakIntervalSeconds: Int = 300  // 5 мин

    /// Пауза от ApplicationMonitor или InactivityMonitor
    private var isPausedByApp: Bool = false

    private var timer: Timer?

    // MARK: - Callbacks
    var onBreakStarted: (() -> Void)?
    var onWorkStarted: (() -> Void)?
    var onBreakEnding: (() -> Void)?   // уведомление за 15 сек до конца рабочего интервала
    var onBreakExpired: (() -> Void)?  // перерыв истёк естественно — оверлей ждёт закрытия

    // MARK: - Constants
    private let notificationBeforeBreakSeconds = 15

    // MARK: - Initialization
    override init() {
        super.init()
    }

    // MARK: - Public: lifecycle

    func start() {
        guard state == .idle else { return }
        resetToWork()
    }

    // MARK: - Public: manual pause (от пользователя через меню)

    func pauseManually() {
        isPausedManually = true
    }

    func resumeManually() {
        isPausedManually = false
    }

    func toggleManualPause() {
        if isPausedManually { resumeManually() } else { pauseManually() }
    }

    // MARK: - Public: app pause (от ApplicationMonitor / InactivityMonitor)

    func pauseByApp() {
        guard !isPausedByApp else { return }
        isPausedByApp = true
        Self.log.notice("pauseByApp: paused (state=\(String(describing: self.state), privacy: .public), timeRemaining=\(self.timeRemaining, privacy: .public))")
    }

    func resumeByApp() {
        guard isPausedByApp else { return }
        isPausedByApp = false
        Self.log.notice("resumeByApp: resumed (state=\(String(describing: self.state), privacy: .public), timeRemaining=\(self.timeRemaining, privacy: .public))")
    }

    // MARK: - Public: actions

    func skip() {
        guard state == .onBreak || state == .breakExpired else { return }
        resetToWork()
    }

    /// Пропустить ещё не начавшийся перерыв (из уведомления за 15 сек)
    func skipUpcomingBreak() {
        resetToWork()
    }

    func doBreakNow() {
        stopTimer()
        state = .onBreak
        isWorkInterval = false
        timeRemaining = breakIntervalSeconds
        onBreakStarted?()
        resumeTimer()
    }

    func updateIntervals(work: Int, breakInterval: Int) {
        workIntervalSeconds = work
        breakIntervalSeconds = breakInterval

        // Если идёт рабочий интервал и осталось больше, чем новое значение — сбросить к новому
        if isWorkInterval && timeRemaining > workIntervalSeconds {
            timeRemaining = workIntervalSeconds
        }
    }

    // MARK: - Sleep/Wake

    /// Спек: если сон >= длительности перерыва → новый цикл, иначе вычесть время
    func handleSleepWake(sleepDuration: TimeInterval) {
        let sleepSeconds = Int(sleepDuration)
        Self.log.notice("handleSleepWake: slept=\(sleepSeconds, privacy: .public)s, state=\(String(describing: self.state), privacy: .public), timeRemaining=\(self.timeRemaining, privacy: .public)")

        if sleepSeconds >= breakIntervalSeconds {
            Self.log.notice("sleep ≥ breakInterval → resetToWork (break skipped)")
            resetToWork()
        } else {
            timeRemaining = max(0, timeRemaining - sleepSeconds)
            if timeRemaining == 0 {
                transitionState()
            }
        }
    }

    // MARK: - Inactivity reset

    func handleInactivity() {
        guard state == .working else { return }
        resetToWork()
    }

    // MARK: - Private

    private func resumeTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isPausedManually && !isPausedByApp else { return }

        // Уведомление за 15 сек до конца рабочего интервала
        if isWorkInterval && timeRemaining == notificationBeforeBreakSeconds {
            onBreakEnding?()
        }

        timeRemaining -= 1

        if timeRemaining <= 0 {
            transitionState()
        }
    }

    private func transitionState() {
        if isWorkInterval {
            stopTimer()
            state = .onBreak
            isWorkInterval = false
            timeRemaining = breakIntervalSeconds
            Self.log.notice("→ onBreak (duration=\(self.breakIntervalSeconds, privacy: .public)s); firing onBreakStarted")
            onBreakStarted?()
            resumeTimer()
        } else {
            // Перерыв истёк — останавливаем таймер и ждём, пока пользователь закроет оверлей
            stopTimer()
            state = .breakExpired
            timeRemaining = 0
            Self.log.notice("→ breakExpired; firing onBreakExpired")
            onBreakExpired?()
        }
    }

    private func resetToWork() {
        stopTimer()
        state = .working
        isWorkInterval = true
        timeRemaining = workIntervalSeconds
        onWorkStarted?()
        resumeTimer()
    }
}
