//
//  RecessEyesApp.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import SwiftUI

@main
struct RecessEyesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Пустой body, так как всё управление идёт через AppDelegate
        Settings {
            EmptyView()
        }
    }
}
