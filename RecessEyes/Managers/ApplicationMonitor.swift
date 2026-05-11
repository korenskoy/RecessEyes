//
//  ApplicationMonitor.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import AppKit
import Combine

/// Монитор активного приложения для автоматической паузы
class ApplicationMonitor: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var activeApplication: NSRunningApplication?
    @Published var shouldPause: Bool = false
    
    // MARK: - Properties
    private var monitoringTimer: Timer?
    private var pausedAppBundleIds: Set<String> = []
    
    var onPauseStateChanged: ((Bool) -> Void)?
    
    // MARK: - Public Methods
    func setUpPausedApps(_ bundleIds: [String]) {
        pausedAppBundleIds = Set(bundleIds)
    }
    
    func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkActiveApplication()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - Private Methods
    private func checkActiveApplication() {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        
        if frontmostApp != activeApplication {
            activeApplication = frontmostApp
        }
        
        let newShouldPause = shouldPauseForApp(frontmostApp)
        
        if newShouldPause != shouldPause {
            shouldPause = newShouldPause
            onPauseStateChanged?(newShouldPause)
        }
    }
    
    private func shouldPauseForApp(_ app: NSRunningApplication?) -> Bool {
        guard let bundleId = app?.bundleIdentifier else { return false }
        return pausedAppBundleIds.contains(bundleId)
    }
    
}
