//
//  OverlayWindowManager.swift
//  RecessEyes
//

import AppKit
import SwiftUI
import os.log

/// NSPanel без рамки, который всегда может стать key-окном
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Менеджер окон оверлея для блокировки экрана
class OverlayWindowManager: NSObject {
    private static let log = Logger(subsystem: "ru.korenskoy.RecessEyes", category: "Overlay")

    // MARK: - Properties
    private var overlayWindows: [NSPanel] = []

    // Флаг: перерыв истёк естественно, оверлей ждёт закрытия пользователем
    private var isBreakExpired: Bool = false

    // Один глобальный Esc-обработчик для всех панелей
    private var escEventMonitor: Any?

    var onSkip: (() -> Void)?
    var onLockScreen: (() -> Void)?

    // MARK: - Public Methods

    /// Показать оверлей перерыва на всех экранах
    func showBreakOverlay(getTimeRemaining: @escaping () -> Int,
                          getTotalDuration: @escaping () -> Int) {
        Self.log.notice("showBreakOverlay called; activation policy=\(NSApp.activationPolicy().rawValue)")
        hideAllOverlays()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.startEscapeMonitor()
            NSApp.activate(ignoringOtherApps: true)
            let screens = NSScreen.screens
            // One tip per break, shared across every screen.
            let tipIndex = Int.random(in: 1...BreakOverlayView.tipCount)
            Self.log.notice("creating panels for \(screens.count, privacy: .public) screen(s); isActive=\(NSApp.isActive); tipIndex=\(tipIndex, privacy: .public)")
            for (index, screen) in screens.enumerated() {
                let panel = self.createOverlayPanel(
                    for: screen,
                    getTimeRemaining: getTimeRemaining,
                    getTotalDuration: getTotalDuration,
                    tipIndex: tipIndex
                )
                panel.makeKeyAndOrderFront(nil)
                // Force-front regardless of app activation state — needed because
                // .accessory apps don't fully "activate" and the panel can otherwise
                // sit behind an active fullscreen app.
                panel.orderFrontRegardless()
                Self.log.notice("panel[\(index, privacy: .public)] frame=\(NSStringFromRect(panel.frame), privacy: .public) visible=\(panel.isVisible) level=\(panel.level.rawValue)")
                self.overlayWindows.append(panel)
            }
        }
    }

    /// Перевести оверлей в режим "перерыв истёк — ждём закрытия"
    func markBreakExpired() {
        isBreakExpired = true
    }

    /// Скрыть все оверлеи
    func hideAllOverlays() {
        if !overlayWindows.isEmpty {
            Self.log.notice("hideAllOverlays: closing \(self.overlayWindows.count, privacy: .public) panel(s)")
        }
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        isBreakExpired = false
        stopEscapeMonitor()
    }

    // MARK: - Private: panels

    private func createOverlayPanel(for screen: NSScreen,
                                    getTimeRemaining: @escaping () -> Int,
                                    getTotalDuration: @escaping () -> Int,
                                    tipIndex: Int) -> NSPanel {
        let panel = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        // Keep on top across spaces, over fullscreen apps, and even when the
        // accessory-policy app isn't the active app.
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        let overlayView = BreakOverlayView(
            getTimeRemaining: getTimeRemaining,
            getTotalDuration: getTotalDuration,
            isExpired: { [weak self] in self?.isBreakExpired ?? false },
            tipIndex: tipIndex,
            onSkip: { [weak self] in
                self?.onSkip?()
                self?.hideAllOverlays()
            },
            onLockScreen: { [weak self] in
                self?.onLockScreen?()
            }
        )

        // Frosted glass effect
        let vfxView = NSVisualEffectView()
        vfxView.material = .fullScreenUI
        vfxView.blendingMode = .behindWindow
        vfxView.state = .active
        vfxView.appearance = NSAppearance(named: .darkAqua)

        let hostingView = NSHostingView(rootView: overlayView.localizedLayoutDirection())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        vfxView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: vfxView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: vfxView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: vfxView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: vfxView.bottomAnchor),
        ])
        panel.contentView = vfxView

        return panel
    }

    // MARK: - Private: Esc handler

    private func startEscapeMonitor() {
        guard escEventMonitor == nil else { return }

        escEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53 else { return event } // 53 = Esc
            self.onSkip?()
            self.hideAllOverlays()
            return nil
        }
    }

    private func stopEscapeMonitor() {
        if let monitor = escEventMonitor {
            NSEvent.removeMonitor(monitor)
            escEventMonitor = nil
        }
    }
}
