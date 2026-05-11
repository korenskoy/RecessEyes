//
//  TimerState.swift
//  RecessEyes
//
//  Created by Антон Коренской on 18.02.2026.
//

import Foundation

/// Состояние таймера приложения
enum TimerState {
    case idle          // Не запущен
    case working       // Рабочее время
    case onBreak       // Время перерыва (идёт отсчёт)
    case breakExpired  // Перерыв истёк, ждём закрытия оверлея пользователем
    case paused        // Приостановлен
}
