import Foundation
import AVFoundation

/// Thread-safe programmatic keystroke mechanic audio synthesizer engine.
final class TypewriterAudioEngine {
    static let shared = TypewriterAudioEngine()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    // Synthesizer voice states - protected by stateLock
    private var phase: Double = 0.0
    private var amplitude: Double = 0.0
    private var decayRate: Double = 0.0
    private var frequency: Double = 1000.0
    private var noiseFilter: Double = 0.0

    private let sampleRate: Double = 44100.0
    private let stateLock = NSLock()

    private init() {
        setupAudio()
    }

    private func setupAudio() {
        sourceNode = AVAudioSourceNode { [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // Thread synchronization: acquire the state lock for the duration of the sample frame processing loop
            self.stateLock.lock()
            defer { self.stateLock.unlock() }

            for frame in 0..<Int(frameCount) {
                var sample = 0.0

                if self.amplitude > 0.0005 {
                    // Damped sine wave frequency component (deep mechanical thud)
                    let sine = sin(self.phase)
                    
                    // Soft low-passed friction noise (mechanical felt/paper contact)
                    let rawNoise = Double.random(in: -1.0...1.0)
                    self.noiseFilter = self.noiseFilter * 0.70 + rawNoise * 0.30
                    let noise = self.noiseFilter
                    
                    // Mix deep thud + soft friction click
                    sample = (sine * 0.40 + noise * 0.60) * self.amplitude

                    // Advance tone phase
                    self.phase += 2.0 * .pi * self.frequency / self.sampleRate
                    if self.phase > 2.0 * .pi {
                        self.phase -= 2.0 * .pi
                    }

                    // Logarithmic amplitude decay
                    self.amplitude *= self.decayRate
                } else {
                    self.amplitude = 0.0
                }

                // Write mono stream into left and right channel buffers
                for buffer in buffers {
                    guard let ptr = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    ptr[frame] = Float(sample)
                }
            }
            return noErr
        }

        guard let sourceNode = sourceNode else { return }
        engine.attach(sourceNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("[TypewriterAudioEngine] start error: \(error)")
        }
    }

    /// Triggers a mechanical keystroke "clack" with random pitch variation.
    func playClick() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        phase = 0.0
        // Deep mechanical pitch variation that sounds pleasant and organic
        frequency = Double.random(in: 120.0...170.0)
        decayRate = 0.993 // Fast, tight decay for clean tactile keytaps
        amplitude = 0.06 // Soft, non-distracting background level
    }

    /// Triggers a retro mechanical carriage return "chime" bell resonance.
    func playChime() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        phase = 0.0
        frequency = 1250.0 // Soft, warm bell frequency (E6 musical note equivalent)
        decayRate = 0.9994 // Slower decay for gentle bell resonance
        amplitude = 0.07 // Extremely gentle chime level
    }
}
