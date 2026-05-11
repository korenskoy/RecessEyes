//
//  OverlayWindowManager.swift
//  RecessEyes
//

import AppKit
import SwiftUI

/// NSPanel без рамки, который всегда может стать key-окном
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Менеджер окон оверлея для блокировки экрана
class OverlayWindowManager: NSObject {
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
        hideAllOverlays()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.startEscapeMonitor()
            NSApp.activate(ignoringOtherApps: true)
            for screen in NSScreen.screens {
                let panel = self.createOverlayPanel(
                    for: screen,
                    getTimeRemaining: getTimeRemaining,
                    getTotalDuration: getTotalDuration
                )
                panel.makeKeyAndOrderFront(nil)
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
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        isBreakExpired = false
        stopEscapeMonitor()
    }

    // MARK: - Private: panels

    private func createOverlayPanel(for screen: NSScreen,
                                    getTimeRemaining: @escaping () -> Int,
                                    getTotalDuration: @escaping () -> Int) -> NSPanel {
        let panel = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let overlayView = BreakOverlayView(
            getTimeRemaining: getTimeRemaining,
            getTotalDuration: getTotalDuration,
            isExpired: { [weak self] in self?.isBreakExpired ?? false },
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
