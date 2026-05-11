//
//  LaunchAtLoginManager.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation
import ServiceManagement

struct LaunchAtLoginManager {

    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[LaunchAtLogin] \(error.localizedDescription)")
            }
        }
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
