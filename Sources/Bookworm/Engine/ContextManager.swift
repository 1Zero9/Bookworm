import Foundation

enum ContextManager {

    // MARK: - Narrative Audit prompt

    static func narrativeAuditPrompt(for chapter: Chapter, book: Book) -> String {
        let ledger   = book.coreLedger
        let detected = detectCharacters(in: chapter.rawText, vault: book.worldCharacters)

        // Limit to last ~1500 words to save tokens
        let words = chapter.rawText.split(separator: " ")
        let draft = words.suffix(1500).joined(separator: " ")

        var p = "You are a sharp, honest fiction editor. Analyse the chapter excerpt below.\n\n"

        p += "## WORLD CONTEXT\n"
        if !ledger.genre.isEmpty             { p += "Genre: \(ledger.genre)\n" }
        if !ledger.tone.isEmpty              { p += "Tone: \(ledger.tone)\n" }
        p +=                                   "Spelling: \(ledger.spellingConvention)\n"
        if !ledger.techOrMagicSystem.isEmpty { p += "System: \(ledger.techOrMagicSystem)\n" }
        if !ledger.hardRules.isEmpty         { p += "Hard rules: \(ledger.hardRules)\n" }
        if !ledger.styleNotes.isEmpty        { p += "Style: \(ledger.styleNotes)\n" }

        if !detected.isEmpty {
            p += "\n## CHARACTERS IN THIS SCENE\n"
            for c in detected {
                p += "**\(c.name)**"
                if !c.physicalDescription.isEmpty  { p += " — \(c.physicalDescription)" }
                if !c.psychologicalProfile.isEmpty { p += ". Psychology: \(c.psychologicalProfile)" }
                if !c.personalVoice.isEmpty        { p += ". Voice: \(c.personalVoice)" }
                p += "\n"
            }
        }

        p += """

        ## CHAPTER: "\(chapter.title)"
        \(draft)

        ## YOUR TASK
        Flag specific passages in three categories:
        - **Cliché** — overused phrases or metaphors
        - **Wiki-voice** — author explaining the world rather than showing it through action/dialogue
        - **Emotional gap** — a character reaction that feels unearned, missing, or inconsistent with their profile

        Return ONLY valid JSON — no markdown fences, no extra text:
        {
          "annotations": [
            {
              "quote": "verbatim text from the chapter (max 80 chars, must match exactly)",
              "note": "concise editorial note",
              "tag": "issue"
            }
          ]
        }

        Rules:
        - "tag" must be "issue" for clichés/wiki-voice, or "query" for emotional gaps
        - Quotes must appear verbatim in the text above
        - Maximum 12 annotations
        - If no issues found, return {"annotations":[]}
        """

        return p
    }

    // MARK: - Character detection

    static func detectCharacters(in text: String, vault: [WorldCharacter]) -> [WorldCharacter] {
        guard !text.isEmpty else { return [] }
        return vault.filter { char in
            var targets = [char.name]
            let firstName = char.name.split(separator: " ").first.map(String.init) ?? char.name
            if firstName != char.name {
                targets.append(firstName)
            }
            targets.append(contentsOf: char.aliasList)
            
            for target in targets {
                let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                let escaped = NSRegularExpression.escapedPattern(for: trimmed)
                let pattern = "\\b\(escaped)\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(text.startIndex..<text.endIndex, in: text)
                    if regex.firstMatch(in: text, options: [], range: range) != nil {
                        return true
                    }
                } else {
                    if text.range(of: trimmed, options: [.caseInsensitive]) != nil {
                        return true
                    }
                }
            }
            return false
        }
    }

    // MARK: - Parse & apply audit response

    struct AuditItem: Decodable {
        let quote: String
        let note:  String
        let tag:   String
    }

    private struct AuditResponse: Decodable {
        let annotations: [AuditItem]
    }

    static func parseAuditResponse(_ raw: String) throws -> [AuditItem] {
        // Strip markdown code fences if the model adds them
        var json = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```json") { json = String(json.dropFirst(7)) }
        if json.hasPrefix("```")     { json = String(json.dropFirst(3)) }
        if json.hasSuffix("```")     { json = String(json.dropLast(3)) }
        json = json.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = json.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode(AuditResponse.self, from: data).annotations
    }

    static func applyAuditToChapter(_ items: [AuditItem], chapter: Chapter) {
        let ns = chapter.rawText as NSString
        for item in items {
            // Try exact match first, then case-insensitive
            var range = ns.range(of: item.quote)
            if range.location == NSNotFound {
                range = ns.range(of: item.quote, options: [.caseInsensitive, .diacriticInsensitive])
            }
            guard range.location != NSNotFound else { continue }

            let tag: AnnotationTag
            switch item.tag.lowercased() {
            case "issue":  tag = .issue
            case "query":  tag = .query
            case "strong": tag = .strong
            default:       tag = .note
            }
            chapter.annotations.append(Annotation(
                start: range.location,
                end:   range.location + range.length,
                note:  item.note,
                tag:   tag
            ))
        }
        chapter.annotations.sort { $0.start < $1.start }
    }
}
