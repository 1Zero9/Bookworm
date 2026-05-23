import Foundation

struct AttributedSentence: Identifiable, Equatable {
    let id: UUID
    let text: String
    let range: NSRange
    let speakerCharacterID: UUID?
    let speakerName: String?
    let isDialogue: Bool
    
    init(id: UUID = UUID(), text: String, range: NSRange, speakerCharacterID: UUID? = nil, speakerName: String? = nil, isDialogue: Bool = false) {
        self.id = id
        self.text = text
        self.range = range
        self.speakerCharacterID = speakerCharacterID
        self.speakerName = speakerName
        self.isDialogue = isDialogue
    }
}

final class DialogueAttributionEngine {
    
    /// Parses raw text into sentence segments, attributing dialogue sentences to characters using paragraph context and name searches.
    static func parse(text: String, worldCharacters: [WorldCharacter]) -> [AttributedSentence] {
        var result: [AttributedSentence] = []
        let nsText = text as NSString
        
        // Segment the text into paragraphs. We track each paragraph's range so we can associate sentences inside it.
        var paragraphRanges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsText.length)
        
        while searchRange.location < nsText.length {
            let paragraphRange = nsText.lineRange(for: NSRange(location: searchRange.location, length: 0))
            paragraphRanges.append(paragraphRange)
            searchRange.location = paragraphRange.location + paragraphRange.length
            if paragraphRange.length == 0 { break } // prevent infinite loop
        }
        
        // Regular expression to find sentences.
        // Matches sentences ending with periods, exclamation marks, question marks, or ellipses.
        let sentencePattern = "[^.!?]+([.!?]+|\u{2026})?"
        guard let sentenceRegex = try? NSRegularExpression(pattern: sentencePattern, options: []) else { return [] }
        
        // We process paragraph by paragraph to build local context
        var lastSpeakerID: UUID? = nil
        var lastSpeakerName: String? = nil
        
        for pRange in paragraphRanges {
            let paragraphText = nsText.substring(with: pRange)
            let trimmedP = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedP.isEmpty else { continue }
            
            // Find which characters are mentioned in this paragraph.
            var charactersMentionedInParagraph: [WorldCharacter] = []
            for character in worldCharacters {
                let name = character.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                
                let namePattern = "\\b\(NSRegularExpression.escapedPattern(for: name))\\b"
                if let nameRegex = try? NSRegularExpression(pattern: namePattern, options: [.caseInsensitive]),
                   nameRegex.firstMatch(in: paragraphText, options: [], range: NSRange(location: 0, length: paragraphText.utf16.count)) != nil {
                    charactersMentionedInParagraph.append(character)
                    continue
                }
                
                // Fallback: match first/last name if it's more than 2 chars
                let parts = name.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                var matchedPart = false
                for part in parts {
                    let partPattern = "\\b\(NSRegularExpression.escapedPattern(for: part))\\b"
                    if let partRegex = try? NSRegularExpression(pattern: partPattern, options: [.caseInsensitive]),
                       partRegex.firstMatch(in: paragraphText, options: [], range: NSRange(location: 0, length: paragraphText.utf16.count)) != nil {
                        charactersMentionedInParagraph.append(character)
                        matchedPart = true
                        break
                    }
                }
                if matchedPart { continue }
            }
            
            // Find all sentences within this paragraph range
            let sentencesInParagraph = sentenceRegex.matches(in: text, options: [], range: pRange)
            
            for match in sentencesInParagraph {
                let sRange = match.range
                let sentenceText = nsText.substring(with: sRange)
                let trimmedS = sentenceText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedS.isEmpty else { continue }
                
                // Determine if it has dialogue quotes
                let hasQuotes = sentenceText.contains("\"") || sentenceText.contains("“") || sentenceText.contains("”") || sentenceText.contains("‘") || sentenceText.contains("’") || sentenceText.contains("'")
                
                if hasQuotes {
                    // 1. If exactly one character is mentioned in the paragraph, attribute to that character
                    if charactersMentionedInParagraph.count == 1 {
                        let char = charactersMentionedInParagraph[0]
                        lastSpeakerID = char.id
                        lastSpeakerName = char.name
                    }
                    // 2. If multiple characters are mentioned in the paragraph, find the closest one to this sentence
                    else if charactersMentionedInParagraph.count > 1 {
                        var bestChar: WorldCharacter? = nil
                        var bestDistance = Int.max
                        
                        for char in charactersMentionedInParagraph {
                            let name = char.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let parts = [name] + name.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
                            
                            for part in parts {
                                let partPattern = "\\b\(NSRegularExpression.escapedPattern(for: part))\\b"
                                if let nameRegex = try? NSRegularExpression(pattern: partPattern, options: [.caseInsensitive]) {
                                    let nameMatches = nameRegex.matches(in: paragraphText, options: [], range: NSRange(location: 0, length: paragraphText.utf16.count))
                                    for nameMatch in nameMatches {
                                        // Convert paragraph-relative location to global location
                                        let globalNameLoc = pRange.location + nameMatch.range.location
                                        let distance = abs(globalNameLoc - sRange.location)
                                        if distance < bestDistance {
                                            bestDistance = distance
                                            bestChar = char
                                        }
                                    }
                                }
                            }
                        }
                        if let matchedChar = bestChar {
                            lastSpeakerID = matchedChar.id
                            lastSpeakerName = matchedChar.name
                        }
                    }
                    // 3. If NO characters are mentioned in the paragraph, fall back to the last active speaker in the conversation
                    
                    result.append(AttributedSentence(
                        id: UUID(),
                        text: trimmedS,
                        range: sRange,
                        speakerCharacterID: lastSpeakerID,
                        speakerName: lastSpeakerName,
                        isDialogue: true
                    ))
                } else {
                    // Non-dialogue: Read by default narrator voice
                    result.append(AttributedSentence(
                        id: UUID(),
                        text: trimmedS,
                        range: sRange,
                        speakerCharacterID: nil,
                        speakerName: nil,
                        isDialogue: false
                    ))
                }
            }
        }
        
        return result
    }
}
