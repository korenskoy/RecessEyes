//
//  AddAppSheet.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Sheet для добавления приложения в список паузы
struct AddAppSheet: View {
    @ObservedObject var pausedAppsManager: PausedAppsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedURL: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Application")
                .font(.headline)
            
            Button("Choose App...") {
                selectApplication()
            }
            
            if let url = selectedURL {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(url.lastPathComponent)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    
                    Button("Add") {
                        addApplication()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(30)
        .frame(width: 300)
    }
    
    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedURL = url
        }
    }
    
    private func addApplication() {
        guard let url = selectedURL else { return }
        
        let bundle = Bundle(url: url)
        let bundleId = bundle?.bundleIdentifier ?? url.lastPathComponent
        let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String ??
                          bundle?.infoDictionary?["CFBundleName"] as? String ??
                          url.lastPathComponent
        
        pausedAppsManager.addApp(bundleId: bundleId, displayName: displayName, url: url)
        dismiss()
    }
}
