//
//  MenuBarView.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import SwiftUI

/// View для отображения в меню-баре
struct MenuBarView: View {
    @State private var timeRemaining: Int = 0
    @State private var state: TimerState = .idle
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye")
                .font(.system(size: 12))
            
            Text(formattedTime)
                .font(.system(size: 11, design: .monospaced))
                .frame(minWidth: 50, alignment: .trailing)
        }
    }
    
    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        
        if minutes >= 10 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func update(timeRemaining: Int, state: TimerState) {
        self.timeRemaining = timeRemaining
        self.state = state
    }
}
