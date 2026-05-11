//
//  SleepWakeMonitor.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation
import AppKit

/// Монитор режима сна/пробуждения системы
class SleepWakeMonitor {
    // MARK: - Properties
    private var sleepTime: Date?
    var onSleepWake: ((TimeInterval) -> Void)?
    
    // MARK: - Initialization
    init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        // Наблюдатели уже настроены в init
    }
    
    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Уведомление о переходе в режим сна
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        // Уведомление о выходе из режима сна
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }
    
    @objc private func screenDidSleep(_ notification: Notification) {
        sleepTime = Date()
    }
    
    @objc private func screenDidWake(_ notification: Notification) {
        guard let sleepStart = sleepTime else { return }
        let sleepDuration = Date().timeIntervalSince(sleepStart)
        sleepTime = nil
        
        onSleepWake?(sleepDuration)
    }
}
