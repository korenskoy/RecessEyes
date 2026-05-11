//
//  ChimePlayer.swift
//  RecessEyes
//
//  Воспроизведение звука перерыва с усилением громкости выше 100%
//  (NSSound и AVAudioPlayer ограничены системной громкостью; AVAudioUnitEQ
//  с положительным gain в дБ позволяет реально сделать звук громче).
//

import AppKit
import AVFoundation
import Foundation

@MainActor
final class ChimePlayer {
    static let shared = ChimePlayer()

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var eq: AVAudioUnitEQ?

    /// Проиграть chime с заданным усилением.
    /// - Parameters:
    ///   - url: путь к аудиофайлу
    ///   - gainDB: усиление в децибелах поверх системной громкости (12 дБ ≈ x4)
    func play(url: URL, gainDB: Float = 12.0) {
        do {
            let file = try AVAudioFile(forReading: url)

            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let eq = AVAudioUnitEQ(numberOfBands: 1)
            eq.globalGain = gainDB

            engine.attach(player)
            engine.attach(eq)
            engine.connect(player, to: eq, format: file.processingFormat)
            engine.connect(eq, to: engine.mainMixerNode, format: file.processingFormat)

            try engine.start()

            player.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor [weak self] in
                    // Подержать engine ещё чуть-чуть, чтобы хвост звука не обрезался
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    self?.engine?.stop()
                    self?.engine = nil
                    self?.player = nil
                    self?.eq = nil
                }
            }
            player.play()

            // Удерживаем ссылки, иначе ARC выгрузит engine во время воспроизведения
            self.engine = engine
            self.player = player
            self.eq = eq
        } catch {
            // Fallback: системный NSSound (макс. громкость = 1.0)
            NSSound(contentsOf: url, byReference: false)?.play()
        }
    }
}
