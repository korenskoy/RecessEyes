//
//  PausedApplication.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation
import AppKit

/// Приложение, при активации которого таймер ставится на паузу
struct PausedApplication: Identifiable {
    let bundleId: String
    var displayName: String
    var isEnabled: Bool
    var icon: NSImage?

    var id: String { bundleId }
}
