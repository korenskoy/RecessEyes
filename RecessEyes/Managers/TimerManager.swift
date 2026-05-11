//
//  TimerManager.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation
import Combine

/// Менеджер таймера, управляющий отсчётом и состояниями
class TimerManager: NSObject, ObservableObject {
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
        isPausedByApp = true
    }

    func resumeByApp() {
        isPausedByApp = false
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

        if sleepSeconds >= breakIntervalSeconds {
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
            onBreakStarted?()
            resumeTimer()
        } else {
            // Перерыв истёк — останавливаем таймер и ждём, пока пользователь закроет оверлей
            stopTimer()
            state = .breakExpired
            timeRemaining = 0
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
