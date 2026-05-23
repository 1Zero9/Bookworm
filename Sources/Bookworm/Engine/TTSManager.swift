import AVFoundation
import Combine
import AppKit

// MARK: - Models

struct TTSVoice: Identifiable, Hashable {
    let id: String
    let name: String
    let quality: String // "Premium", "Enhanced", "Standard", "Cloud"
    let language: String
}

// MARK: - TTSProvider Protocol

protocol TTSProvider: AnyObject {
    var isPlaying: Bool { get }
    var isPaused: Bool { get }
    var spokenRange: NSRange? { get set }
    
    func speak(_ text: String, fromOffset offset: Int, rate: Float, voiceID: String, onRangeUpdate: @escaping (NSRange) -> Void, onCompletion: @escaping () -> Void)
    func pause()
    func resume()
    func stop()
    func reloadVoices() -> [TTSVoice]
}

// MARK: - Local macOS Implementation

final class LocalSystemTTSProvider: NSObject, TTSProvider, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synth = AVSpeechSynthesizer()
    private let speechQueue = DispatchQueue(label: "com.bookworm.speechQueue", qos: .userInitiated)
    private var intentionallyStopping = false
    private var activeUtteranceOffset = 0
    
    var isPlaying = false
    var isPaused = false
    var spokenRange: NSRange? = nil
    
    private var onRangeUpdateHandler: ((NSRange) -> Void)?
    private var onCompletionHandler: (() -> Void)?
    
    override init() {
        super.init()
        synth.delegate = self
    }
    
    func speak(_ text: String, fromOffset offset: Int, rate: Float, voiceID: String, onRangeUpdate: @escaping (NSRange) -> Void, onCompletion: @escaping () -> Void) {
        self.onRangeUpdateHandler = onRangeUpdate
        self.onCompletionHandler = onCompletion
        
        isPlaying = true
        isPaused = false
        
        speechQueue.async { [weak self] in
            guard let self else { return }
            
            self.intentionallyStopping = true
            self.synth.stopSpeaking(at: .immediate)
            self.intentionallyStopping = false
            
            self.activeUtteranceOffset = offset
            
            // Take a slice of the prose from the offset to the end
            let rawSpeechString: String
            if offset < text.count {
                let index = text.index(text.startIndex, offsetBy: offset)
                rawSpeechString = String(text[index...])
            } else {
                rawSpeechString = ""
            }
            
            let trimmed = rawSpeechString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.isPaused = false
                    self.spokenRange = nil
                    onCompletion()
                }
                return
            }
            
            let utterance = AVSpeechUtterance(string: rawSpeechString)
            if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == voiceID }) {
                utterance.voice = voice
            }
            
            // Apple neural voices scale naturally using rate
            utterance.rate = rate
            
            self.synth.speak(utterance)
        }
    }
    
    func pause() {
        isPlaying = false
        isPaused = true
        speechQueue.async { [weak self] in
            self?.synth.pauseSpeaking(at: .word)
        }
    }
    
    func resume() {
        isPlaying = true
        isPaused = false
        speechQueue.async { [weak self] in
            self?.synth.continueSpeaking()
        }
    }
    
    func stop() {
        isPlaying = false
        isPaused = false
        spokenRange = nil
        speechQueue.async { [weak self] in
            guard let self else { return }
            self.intentionallyStopping = true
            self.synth.stopSpeaking(at: .immediate)
            self.intentionallyStopping = false
        }
    }
    
    func reloadVoices() -> [TTSVoice] {
        // Filter out low-fidelity system voices
        let jokeVoices = ["albert", "bad news", "bells", "boing", "bubbles", "cellos", "good news", 
                          "hysterical", "organ", "pipe organ", "princess", "trinoids", "whisper", "zarvox", "deranged"]
        
        let speechVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .filter { voice in
                let nameLower = voice.name.lowercased()
                return !jokeVoices.contains { nameLower.contains($0) }
            }
            .sorted { $0.name < $1.name }
            
        let converted = speechVoices.map { voice in
            let qualityStr: String
            switch voice.quality {
            case .premium:  qualityStr = "Premium"
            case .enhanced: qualityStr = "Enhanced"
            default:        qualityStr = "Standard"
            }
            return TTSVoice(id: voice.identifier, name: voice.name, quality: qualityStr, language: voice.language)
        }
        
        // Retain only premium or enhanced voices to prevent robotic standard voice fallbacks
        let highFidelity = converted.filter { $0.quality == "Premium" || $0.quality == "Enhanced" }
        
        // Fallback: If no high-fidelity voices are downloaded, supply natural standard voices
        if highFidelity.isEmpty {
            let naturalDefaultNames = ["samantha", "alex", "daniel", "karen", "tessa", "moira", "victoria", "fiona"]
            return converted.filter { voice in
                let nameL = voice.name.lowercased()
                return naturalDefaultNames.contains { nameL.contains($0) }
            }
        }
        
        return highFidelity
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        guard !intentionallyStopping else { return }
        let absLocation = activeUtteranceOffset + characterRange.location
        let absRange = NSRange(location: absLocation, length: characterRange.length)
        onRangeUpdateHandler?(absRange)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        guard !intentionallyStopping else { return }
        isPlaying = false
        isPaused = false
        spokenRange = nil
        onCompletionHandler?()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        guard !intentionallyStopping else { return }
        isPlaying = false
        isPaused = false
        spokenRange = nil
    }
}

// MARK: - TTSManager Coordinator

final class TTSManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var spokenRange: NSRange? = nil
    @Published var bookmarks: [UUID: Int] = [:]
    @Published var activeChapterID: UUID? = nil
    
    @Published var premiumVoices: [TTSVoice] = []
    @Published var enhancedVoices: [TTSVoice] = []
    @Published var standardVoices: [TTSVoice] = []
    @Published var allVoices: [TTSVoice] = []
    @Published var selectedVoiceID: String = ""
    @Published var rate: Float = 0.44 // Warmer, more deliberate default narration rate
    
    private let provider: TTSProvider
    var activeText: String = ""
    
    // Sequential playback state
    private var sentenceQueue: [AttributedSentence] = []
    private var currentSentenceIndex: Int = 0
    private var activeCharacters: [WorldCharacter] = []
    private var isSequentialPlayback = false
    
    init(provider: TTSProvider = LocalSystemTTSProvider()) {
        self.provider = provider
        super.init()
        self.reloadVoices()
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc private func appDidBecomeActive() { reloadVoices() }
    
    func reloadVoices() {
        let voices = provider.reloadVoices()
        self.allVoices = voices
        self.premiumVoices = voices.filter { $0.quality == "Premium" }
        self.enhancedVoices = voices.filter { $0.quality == "Enhanced" }
        self.standardVoices = voices.filter { $0.quality == "Standard" }
        
        if selectedVoiceID.isEmpty || !voices.contains(where: { $0.id == selectedVoiceID }) {
            if let bestPremium = premiumVoices.first {
                selectedVoiceID = bestPremium.id
            } else if let bestEnhanced = enhancedVoices.first {
                selectedVoiceID = bestEnhanced.id
            } else if let bestStandard = standardVoices.first {
                selectedVoiceID = bestStandard.id
            } else {
                selectedVoiceID = voices.first?.id ?? ""
            }
        }
    }
    
    var selectedVoice: TTSVoice? {
        allVoices.first { $0.id == selectedVoiceID }
    }
    
    func speakTest(_ text: String, voiceID: String) {
        self.stop()
        provider.speak(text, fromOffset: 0, rate: rate, voiceID: voiceID, onRangeUpdate: { _ in }, onCompletion: {})
    }
    
    func speak(_ text: String, chapterID: UUID? = nil, fromOffset offset: Int = 0, worldCharacters: [WorldCharacter] = []) {
        self.activeText = text
        self.activeChapterID = chapterID
        self.activeCharacters = worldCharacters
        
        // 1. Parse sentences using DialogueAttributionEngine
        let allSentences = DialogueAttributionEngine.parse(text: text, worldCharacters: worldCharacters)
        
        // 2. Filter or find which sentence index matches the offset
        let startIndex = allSentences.firstIndex(where: { $0.range.contains(offset) || $0.range.location >= offset }) ?? 0
        
        // 3. Keep track of the queue
        self.sentenceQueue = allSentences
        self.currentSentenceIndex = startIndex
        self.isSequentialPlayback = true
        
        // 4. Start sequential playback of the current sentence
        self.speakCurrentSentence()
    }
    
    private func speakCurrentSentence() {
        guard isSequentialPlayback, currentSentenceIndex < sentenceQueue.count else {
            // Reached the end of the chapter playback!
            DispatchQueue.main.async {
                self.isPlaying = false
                self.isPaused = false
                self.spokenRange = nil
                self.isSequentialPlayback = false
            }
            return
        }
        
        let sentence = sentenceQueue[currentSentenceIndex]
        
        // Find which voice identifier to use for this sentence
        let voiceID: String
        if let charID = sentence.speakerCharacterID,
           let character = activeCharacters.first(where: { $0.id == charID }),
           !character.voiceIdentifier.isEmpty {
            voiceID = character.voiceIdentifier
        } else {
            // Fallback to global narration voice selection
            voiceID = selectedVoiceID
        }
        
        provider.speak(activeText, fromOffset: sentence.range.location, rate: rate, voiceID: voiceID, onRangeUpdate: { [weak self] range in
            guard let self else { return }
            DispatchQueue.main.async {
                self.spokenRange = range
                self.isPlaying = self.provider.isPlaying
                self.isPaused = self.provider.isPaused
                
                // Track precise character offset in bookmarks
                if let chID = self.activeChapterID {
                    self.bookmarks[chID] = range.location
                }
            }
        }, onCompletion: { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.isSequentialPlayback {
                    // Advance to the next sentence!
                    self.currentSentenceIndex += 1
                    self.speakCurrentSentence()
                }
            }
        })
        
        self.isPlaying = provider.isPlaying
        self.isPaused = provider.isPaused
    }
    
    func pause() {
        provider.pause()
        self.isPlaying = provider.isPlaying
        self.isPaused = provider.isPaused
    }
    
    func resume() {
        provider.resume()
        self.isPlaying = provider.isPlaying
        self.isPaused = provider.isPaused
    }
    
    func stop() {
        self.isSequentialPlayback = false
        self.sentenceQueue = []
        self.currentSentenceIndex = 0
        if let id = activeChapterID, let range = spokenRange {
            bookmarks[id] = range.location
        }
        provider.stop()
        self.isPlaying = provider.isPlaying
        self.isPaused = provider.isPaused
        self.spokenRange = nil
    }
    
    func clearBookmark(for chapterID: UUID) {
        bookmarks.removeValue(forKey: chapterID)
    }
    
    func skipBackward(seconds: Double = 10) {
        guard let chID = activeChapterID, let range = spokenRange else { return }
        let charOffset = Int(seconds * 15) // ~15 chars per sec at typical speaking rate
        let newOffset = max(0, range.location - charOffset)
        speak(activeText, chapterID: chID, fromOffset: newOffset, worldCharacters: activeCharacters)
    }
    
    func skipForward(seconds: Double = 10) {
        guard let chID = activeChapterID, let range = spokenRange else { return }
        let charOffset = Int(seconds * 15)
        let newOffset = min(activeText.count - 1, range.location + charOffset)
        speak(activeText, chapterID: chID, fromOffset: newOffset, worldCharacters: activeCharacters)
    }
    
    func openVoiceSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Speech",
            "x-apple.systempreferences:com.apple.Accessibility-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.universalaccess?SpeechPanel"
        ]
        
        for urlStr in urls {
            if let url = URL(string: urlStr) {
                if NSWorkspace.shared.open(url) {
                    print("[TTSManager] Opened Spoken Content Settings URL: \(urlStr)")
                    return
                }
            }
        }
    }
}
