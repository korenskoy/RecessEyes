//
//  InactivityMonitor.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation
import IOKit

/// Монитор пользовательской неактивности (мышь + клавиатура)
/// При неактивности >= breakIntervalSeconds вызывает onInactivity
class InactivityMonitor {
    // MARK: - Properties
    var onInactivity: (() -> Void)?

    /// Порог неактивности в секундах (равен breakIntervalSeconds)
    var threshold: TimeInterval = 300

    private var checkTimer: Timer?
    private var alreadyFired: Bool = false

    // MARK: - Public Methods

    func startMonitoring() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkIdleTime()
        }
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func resetFiredFlag() {
        alreadyFired = false
    }

    // MARK: - Private Methods

    private func checkIdleTime() {
        let idle = systemIdleTime()

        if idle >= threshold {
            guard !alreadyFired else { return }
            alreadyFired = true
            onInactivity?()
        } else {
            alreadyFired = false
        }
    }

    private func systemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            service,
            &unmanagedProperties,
            kCFAllocatorDefault,
            0
        ) == KERN_SUCCESS else { return 0 }

        let properties = unmanagedProperties!.takeRetainedValue() as NSDictionary
        guard let idleNs = properties["HIDIdleTime"] as? UInt64 else { return 0 }

        return TimeInterval(idleNs) / 1_000_000_000.0
    }
}
