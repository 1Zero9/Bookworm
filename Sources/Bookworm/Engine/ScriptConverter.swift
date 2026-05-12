import Foundation

struct ScriptConverter {

    static func convert(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var out: [String] = ["[SCENE OPEN]", ""]

        // Group lines: blank lines = paragraph break, single newlines = same paragraph
        let paragraphs: [String] = trimmed
            .components(separatedBy: "\n")
            .reduce(into: [[String]]()) { groups, line in
                let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if l.isEmpty {
                    if !(groups.last?.isEmpty ?? true) { groups.append([]) }
                } else {
                    if groups.isEmpty { groups.append([]) }
                    groups[groups.count - 1].append(l)
                }
            }
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: " ") }

        for (i, para) in paragraphs.enumerated() {
            for block in parseBlocks(para) {
                out += formatBlock(block)
            }
            if i < paragraphs.count - 1 {
                out += ["", "[PAUSE]", ""]
            }
        }

        out += ["", "[END SCENE]"]
        return out.joined(separator: "\n")
    }

    // MARK: - Block types

    enum Block {
        case narration(String)
        case dialogue(speaker: String, line: String, tag: String?)
    }

    // MARK: - Parsing

    static func parseBlocks(_ para: String) -> [Block] {
        // Normalise curly quotes to straight so we can split reliably
        let normalised = para
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")

        // Split on double-quote chars; even indices = narration, odd = dialogue
        let parts = normalised.components(separatedBy: "\"")

        var blocks: [Block] = []

        for (i, part) in parts.enumerated() {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if i % 2 == 0 {
                // Narration / attribution segment
                if !trimmed.isEmpty && !isPureAttribution(trimmed) {
                    blocks.append(.narration(trimmed))
                }
            } else {
                // Quoted dialogue
                guard !trimmed.isEmpty else { continue }
                let prev = i > 0 ? parts[i - 1] : ""
                let next = i + 1 < parts.count ? parts[i + 1] : ""
                let speaker = extractSpeaker(from: prev) ?? extractSpeaker(from: next) ?? "CHARACTER"
                let tag = cleanAttribution(next)
                blocks.append(.dialogue(speaker: speaker, line: trimmed, tag: tag))
            }
        }

        return blocks
    }

    // Short segments that are only attribution noise (", she said,") — suppress as narration
    private static func isPureAttribution(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard words.count <= 6 else { return false }
        return words.contains { speechVerbs.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
    }

    private static func cleanAttribution(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ",")))
        // Only keep attribution if it adds meaningful content beyond just "she said"
        guard !t.isEmpty && !isPureAttribution(t) else { return nil }
        return t
    }

    static let speechVerbs: Set<String> = [
        "said", "asked", "replied", "whispered", "shouted", "muttered",
        "declared", "announced", "called", "cried", "snapped", "growled",
        "breathed", "sighed", "laughed", "added", "continued", "began",
        "answered", "hissed", "barked", "murmured", "yelled", "stated",
        "echoed", "demanded", "insisted", "offered", "agreed"
    ]

    static func extractSpeaker(from text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for (i, word) in words.enumerated() {
            let clean = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            guard speechVerbs.contains(clean) else { continue }
            // Check word before verb
            if i > 0 {
                let prev = words[i - 1].trimmingCharacters(in: .punctuationCharacters)
                if prev.first?.isUppercase == true && prev.count > 1 { return prev.uppercased() }
            }
            // Check word after verb (e.g. "said John")
            if i + 1 < words.count {
                let next = words[i + 1].trimmingCharacters(in: .punctuationCharacters)
                if next.first?.isUppercase == true && next.count > 1 { return next.uppercased() }
            }
        }
        return nil
    }

    // MARK: - Formatting

    static func formatBlock(_ block: Block) -> [String] {
        switch block {
        case .narration(let text):
            return ["[NARRATOR]", text, ""]

        case .dialogue(let speaker, let line, let tag):
            var lines = ["[\(speaker)]", "\"\(line)\""]
            if let t = tag { lines.append("  (\(t))") }
            lines.append("")
            if line.hasSuffix("!") && line.split(separator: " ").count < 7 {
                lines += ["[DRAMATIC BEAT]", ""]
            }
            return lines
        }
    }
}
