import AVFoundation
import Combine
import AppKit

final class TTSManager: NSObject, ObservableObject {
    private let synth = AVSpeechSynthesizer()
    private var intentionallyStopping = false

    // MARK: - Observable state
    @Published var isPlaying = false
    @Published var isPaused  = false
    @Published var currentItemIndex = 0
    @Published var bookmarks: [UUID: Int] = [:]

    // Script items for the current session
    private(set) var items: [SpeechItem] = []
    private var currentChapterID: UUID? = nil

    // MARK: - Voices
    @Published var premiumVoices:  [AVSpeechSynthesisVoice] = []
    @Published var enhancedVoices: [AVSpeechSynthesisVoice] = []
    @Published var standardVoices: [AVSpeechSynthesisVoice] = []
    @Published var allVoices:      [AVSpeechSynthesisVoice] = []
    @Published var selectedVoiceID: String = ""
    @Published var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    // MARK: - Init

    override init() {
        super.init()
        synth.delegate = self
        reloadVoices()
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func appDidBecomeActive() { reloadVoices() }

    func reloadVoices() {
        let all = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
        premiumVoices  = all.filter { $0.quality == .premium }
        enhancedVoices = all.filter { $0.quality == .enhanced }
        standardVoices = all.filter { $0.quality == .default }
        allVoices = all
        if selectedVoiceID.isEmpty || !all.contains(where: { $0.identifier == selectedVoiceID }) {
            selectedVoiceID = (premiumVoices.first ?? enhancedVoices.first ?? standardVoices.first)?.identifier ?? ""
        }
    }

    var selectedVoice: AVSpeechSynthesisVoice? {
        allVoices.first { $0.identifier == selectedVoiceID }
    }

    // MARK: - Playback

    func speakScript(_ script: String, chapterID: UUID? = nil, from startIndex: Int = 0) {
        intentionallyStopping = true
        synth.stopSpeaking(at: .immediate)
        intentionallyStopping = false

        items = buildItems(from: script)
        currentChapterID = chapterID
        currentItemIndex = max(0, min(startIndex, max(0, items.count - 1)))
        speakCurrentItem()
    }

    func speakRaw(_ text: String, chapterID: UUID? = nil) {
        intentionallyStopping = true
        synth.stopSpeaking(at: .immediate)
        intentionallyStopping = false

        items = splitIntoSentences(text).map {
            SpeechItem(text: $0.text, postDelay: $0.pause, pitch: 1.0, rateMultiplier: 1.0, groupIndex: 0)
        }
        currentChapterID = chapterID
        currentItemIndex = 0
        speakCurrentItem()
    }

    /// Seek to the first sentence in a content group (used by tap-to-play in script view).
    func seekToGroup(_ groupIndex: Int, in script: String, chapterID: UUID? = nil) {
        let builtItems = buildItems(from: script)
        let idx = builtItems.firstIndex { $0.groupIndex >= groupIndex } ?? 0
        speakScript(script, chapterID: chapterID, from: idx)
    }

    func pause() {
        synth.pauseSpeaking(at: .word)
        isPlaying = false
        isPaused  = true
    }

    func resume() {
        synth.continueSpeaking()
        isPlaying = true
        isPaused  = false
    }

    func stop() {
        if let id = currentChapterID, !items.isEmpty {
            bookmarks[id] = currentItemIndex
        }
        intentionallyStopping = true
        synth.stopSpeaking(at: .immediate)
        intentionallyStopping = false
        isPlaying = false
        isPaused  = false
    }

    func clearBookmark(for chapterID: UUID) {
        bookmarks.removeValue(forKey: chapterID)
    }

    func openVoiceSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?SpeechPanel")!)
    }

    // MARK: - Private — one item at a time

    private func speakCurrentItem() {
        guard currentItemIndex < items.count else {
            DispatchQueue.main.async { self.isPlaying = false; self.isPaused = false }
            return
        }
        let item = items[currentItemIndex]
        let u = AVSpeechUtterance(string: item.text)
        u.voice             = selectedVoice
        u.rate              = rate * item.rateMultiplier
        u.pitchMultiplier   = item.pitch
        u.postUtteranceDelay = item.postDelay
        synth.speak(u)
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused  = false
        }
    }

    // MARK: - Script → SpeechItem array

    struct SpeechItem {
        let text: String
        let postDelay: TimeInterval
        let pitch: Float
        let rateMultiplier: Float
        let groupIndex: Int   // which content block this belongs to (for tap-to-seek)
    }

    func buildItems(from script: String) -> [SpeechItem] {
        var result: [SpeechItem] = []
        var buffer: [String] = []
        var isDialogue = false
        var speaker = ""
        var group = 0

        func flush(sectionDelay: TimeInterval) {
            guard !buffer.isEmpty else { return }
            let text = buffer.joined(separator: " ")
            buffer = []
            let sentences = splitIntoSentences(text)
            for (i, s) in sentences.enumerated() {
                let delay = (i == sentences.count - 1) ? sectionDelay : s.pause
                let pitch: Float  = isDialogue ? pitchFor(speaker: speaker) : 1.0
                let rateM: Float  = isDialogue ? 1.06 : 1.0
                result.append(SpeechItem(text: s.text, postDelay: delay,
                                         pitch: pitch, rateMultiplier: rateM, groupIndex: group))
            }
            group += 1
        }

        for raw in script.components(separatedBy: "\n") {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            switch t {
            case "[PAUSE]":          flush(sectionDelay: 1.5)
            case "[DRAMATIC BEAT]":  flush(sectionDelay: 2.5)
            case "[SCENE OPEN]":     flush(sectionDelay: 1.0)
            case "[END SCENE]", "[SCENE BREAK]": flush(sectionDelay: 0.8)
            case "[NARRATOR]":
                flush(sectionDelay: 0.6)
                isDialogue = false; speaker = ""
            case let cue where cue.hasPrefix("[") && cue.hasSuffix("]"):
                flush(sectionDelay: 0.4)
                speaker = String(cue.dropFirst().dropLast())
                isDialogue = true
            default:
                buffer.append(t)
            }
        }
        flush(sectionDelay: 0)
        return result
    }

    // MARK: - Sentence splitting with punctuation-aware pauses

    struct Sentence { let text: String; let pause: TimeInterval }

    func splitIntoSentences(_ text: String) -> [Sentence] {
        var result: [Sentence] = []
        var current = ""
        var i = text.startIndex

        func commit(_ pause: TimeInterval) {
            let t = current.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { result.append(Sentence(text: t, pause: pause)) }
            current = ""
        }

        while i < text.endIndex {
            let ch = text[i]
            current.append(ch)
            let next = text.index(after: i)
            let atEnd = next == text.endIndex
            let nextIsSpace = !atEnd && text[next] == " "

            if (ch == "—" || ch == "–") && (atEnd || nextIsSpace) {
                commit(0.20)
                if nextIsSpace { i = next }
            } else if ch == "." && current.hasSuffix("...") && (atEnd || nextIsSpace) {
                commit(0.65)
                if nextIsSpace { i = next }
            } else if (ch == "." || ch == "!" || ch == "?") && (atEnd || nextIsSpace) {
                commit(ch == "." ? 0.35 : 0.45)
                if nextIsSpace { i = next }
            }

            guard i < text.endIndex else { break }
            i = text.index(after: i)
        }

        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { result.append(Sentence(text: tail, pause: 0)) }
        return result.filter { !$0.text.isEmpty }
    }

    private func pitchFor(speaker: String) -> Float {
        guard !speaker.isEmpty else { return 1.0 }
        let hash = speaker.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return 0.88 + Float(abs(hash) % 10) / 10.0 * 0.24
    }
}

// MARK: - Delegate

extension TTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        guard !intentionallyStopping else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.intentionallyStopping else { return }
            self.currentItemIndex += 1
            self.speakCurrentItem()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        guard !intentionallyStopping else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.intentionallyStopping else { return }
            self.isPlaying = false
            self.isPaused  = false
        }
    }
}
