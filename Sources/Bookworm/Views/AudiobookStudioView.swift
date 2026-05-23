import SwiftUI
import AVFoundation

struct AudiobookStudioView: View {
    @Environment(Book.self) private var book
    @EnvironmentObject private var tts: TTSManager

    @State private var hoveredSentenceID: UUID? = nil

    var body: some View {
        if let ch = book.selectedChapter {
            let prose = ch.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if prose.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "waveform")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(AppTheme.accentNarrate)
                        .padding(.bottom, 8)
                    Text("Audiobook Studio")
                        .font(AppTheme.editorialFont(20, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Write your story in the editor canvas, then press the Play button below to listen to your prose narrated in premium audio.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.surface)
            } else {
                let sentences = DialogueAttributionEngine.parse(text: prose, worldCharacters: book.worldCharacters)
                let currentActiveID = activeSentenceID(in: sentences)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(sentences) { sentence in
                                SentenceRow(
                                    sentence: sentence,
                                    isActive: sentence.id == currentActiveID,
                                    isAnyActive: currentActiveID != nil,
                                    hoveredSentenceID: $hoveredSentenceID,
                                    spokenRange: tts.spokenRange
                                )
                                .id(sentence.id)
                                .onTapGesture {
                                    // Tap to seek narration to this sentence's exact character offset
                                    tts.speak(ch.rawText, chapterID: ch.id, fromOffset: sentence.range.location, worldCharacters: book.worldCharacters)
                                }
                            }
                        }
                        .padding(.vertical, 32)
                        .padding(.horizontal, 24)
                    }
                    .background(AppTheme.surface)
                    .onChange(of: currentActiveID) { _, newID in
                        if let newID = newID {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Select a chapter to begin narration rehearsal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.surface)
        }
    }

    // MARK: - Helpers

    private func activeSentenceID(in sentences: [AttributedSentence]) -> UUID? {
        guard tts.isPlaying || tts.isPaused, let spokenRange = tts.spokenRange else { return nil }
        return sentences.first { segment in
            let intersection = NSIntersectionRange(segment.range, spokenRange)
            return intersection.length > 0
        }?.id
    }
}

// MARK: - Individual Sentence Row View

private struct SentenceRow: View {
    let sentence: AttributedSentence
    let isActive: Bool
    let isAnyActive: Bool
    @Binding var hoveredSentenceID: UUID?
    let spokenRange: NSRange?
    
    var isHovered: Bool { hoveredSentenceID == sentence.id }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Interactive Play Indicator on Hover
            ZStack {
                if isActive {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(characterColor(for: sentence.speakerCharacterID))
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                        .transition(.opacity)
                } else {
                    Spacer().frame(width: 12)
                }
            }
            .frame(width: 16, height: 22)
            
            // Text Block containing character-level glowing highlights
            VStack(alignment: .leading, spacing: 4) {
                if let speakerName = sentence.speakerName {
                    Text(speakerName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(characterColor(for: sentence.speakerCharacterID), in: RoundedRectangle(cornerRadius: 4))
                        .padding(.bottom, 2)
                        .help("Dialogue attributed to \(speakerName)")
                }
                
                Text(formattedSentence(sentence, spokenRange: spokenRange))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .foregroundStyle(textColor)
                    .animation(.easeInOut(duration: 0.18), value: isActive)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? characterColor(for: sentence.speakerCharacterID).opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hoveredSentenceID = sentence.id
            } else if hoveredSentenceID == sentence.id {
                hoveredSentenceID = nil
            }
        }
    }

    private var textColor: Color {
        if isActive { return AppTheme.textPrimary }
        if isHovered { return AppTheme.textPrimary.opacity(0.85) }
        return isAnyActive ? AppTheme.textSecondary.opacity(0.5) : AppTheme.textPrimary.opacity(0.8)
    }

    private func characterColor(for id: UUID?) -> Color {
        guard let id = id else { return AppTheme.accentNarrate }
        let colors: [Color] = [.orange, .purple, .cyan, .teal, .indigo, .pink, .yellow, .green]
        return colors[abs(id.hashValue) % colors.count]
    }

    private func formattedSentence(_ segment: AttributedSentence, spokenRange: NSRange?) -> AttributedString {
        var attrStr = AttributedString(segment.text)
        attrStr.font = .system(size: 15, weight: .regular, design: .serif)
        
        guard let spokenRange = spokenRange else {
            return attrStr
        }
        
        let intersection = NSIntersectionRange(segment.range, spokenRange)
        guard intersection.length > 0 else {
            return attrStr
        }
        
        let localStart = intersection.location - segment.range.location
        let localLength = intersection.length
        
        if localStart >= 0 && localStart + localLength <= segment.text.count {
            let startIdx = attrStr.characters.index(attrStr.characters.startIndex, offsetBy: localStart)
            let endIdx = attrStr.characters.index(startIdx, offsetBy: localLength)
            attrStr[startIdx..<endIdx].foregroundColor = characterColor(for: segment.speakerCharacterID)
            attrStr[startIdx..<endIdx].underlineStyle = .single
            attrStr[startIdx..<endIdx].font = .system(size: 15, weight: .bold, design: .serif)
        }
        
        return attrStr
    }
}
