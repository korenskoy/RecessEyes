//
//  EyeDropsReminderManager.swift
//  RecessEyes
//
//  Created by Антон Коренской on 21.02.2026.
//

import Foundation
import UserNotifications

/// Независимый таймер напоминания о каплях для глаз.
/// Работает всегда — не зависит от паузы по приложениям.
class EyeDropsReminderManager {
    // MARK: - Properties

    /// Интервал в секундах между напоминаниями
    var intervalSeconds: Int {
        didSet {
            restartTimer()
        }
    }

    private var timer: Timer?
    private let notificationIdentifier = "eye_drops_reminder"

    // MARK: - Initialization

    init(intervalMinutes: Int) {
        self.intervalSeconds = intervalMinutes * 60
    }

    // MARK: - Public

    func startMonitoring() {
        scheduleTimer()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func updateInterval(minutes: Int) {
        intervalSeconds = minutes * 60
    }

    // MARK: - Private

    private func restartTimer() {
        stopTimer()
        scheduleTimer()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer() {
        guard intervalSeconds > 0 else { return }
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(intervalSeconds),
            repeats: true
        ) { [weak self] _ in
            self?.fireReminder()
        }
    }

    private func fireReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Eye drops time"
        content.body = "Moisturize your eyes"
        content.sound = .default
        content.categoryIdentifier = "EYE_DROPS"
        // interruptionLevel недоступен на macOS < 12 — оставляем дефолт

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil
        )
        // Удаляем предыдущее (если пользователь ещё не закрыл)
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [notificationIdentifier]
        )
        UNUserNotificationCenter.current().add(request)
    }
}
