import AVFoundation
import Foundation

struct BroadcastStingerTemplate: Decodable {
    struct ToneEvent: Decodable {
        let time: Double
        let duration: Double
        let frequency: Double
        let amplitude: Double
        let pan: Double?
        let harmonics: [Double]?
    }

    let baseDuration: Double
    let events: [ToneEvent]
}

@MainActor
public final class CountdownAudioPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private let template: BroadcastStingerTemplate

    public init() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        self.template = try Self.loadTemplate()
    }

    public func play(seconds: Int, volume: Double) throws {
        let duration = max(1, seconds)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let totalDuration = Double(duration) + 1.4
        let frameCapacity = AVAudioFrameCount((totalDuration * sampleRate).rounded(.up))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            return
        }

        buffer.frameLength = frameCapacity
        guard let left = buffer.floatChannelData?[0], let right = buffer.floatChannelData?[1] else {
            return
        }

        let scale = Double(duration) / template.baseDuration

        for tone in template.events {
            let startSample = Int((tone.time * scale * sampleRate).rounded())
            let sampleCount = max(1, Int((tone.duration * scale * sampleRate).rounded()))
            let pan = min(max(tone.pan ?? 0.0, -1.0), 1.0)
            let leftGain = Float((1.0 - pan) * 0.5)
            let rightGain = Float((1.0 + pan) * 0.5)
            let harmonics = tone.harmonics ?? [1.0, 0.35, 0.16]

            for offset in 0..<sampleCount {
                let sampleIndex = startSample + offset
                if sampleIndex >= Int(buffer.frameLength) {
                    break
                }

                let time = Double(offset) / sampleRate
                let normalized = Double(offset) / Double(sampleCount)
                let envelope = envelopeValue(position: normalized)
                let baseAmplitude = tone.amplitude * volume * envelope

                var sampleValue = 0.0
                for (harmonicIndex, harmonicAmplitude) in harmonics.enumerated() {
                    let harmonic = Double(harmonicIndex + 1)
                    let radians = 2.0 * Double.pi * tone.frequency * harmonic * time
                    sampleValue += sin(radians) * harmonicAmplitude
                }

                sampleValue *= baseAmplitude
                left[sampleIndex] += Float(sampleValue) * leftGain
                right[sampleIndex] += Float(sampleValue) * rightGain
            }
        }

        normalize(buffer: buffer)

        player.stop()
        if engine.isRunning == false {
            try engine.start()
        }

        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        player.play()
    }

    private func envelopeValue(position: Double) -> Double {
        switch position {
        case ..<0.08:
            return position / 0.08
        case 0.8...:
            return max(0.0, (1.0 - position) / 0.2)
        default:
            return 1.0
        }
    }

    private func normalize(buffer: AVAudioPCMBuffer) {
        guard let left = buffer.floatChannelData?[0], let right = buffer.floatChannelData?[1] else {
            return
        }

        var peak: Float = 0
        for index in 0..<Int(buffer.frameLength) {
            peak = max(peak, abs(left[index]), abs(right[index]))
        }

        guard peak > 0.95 else {
            return
        }

        let scale: Float = 0.95 / peak
        for index in 0..<Int(buffer.frameLength) {
            left[index] *= scale
            right[index] *= scale
        }
    }

    private static func loadTemplate() throws -> BroadcastStingerTemplate {
        let url = Bundle.module.url(forResource: "broadcast_stinger", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BroadcastStingerTemplate.self, from: data)
    }
}
