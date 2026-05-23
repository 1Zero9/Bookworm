import Foundation

enum DiffOp: String, Codable, Hashable {
    case equal
    case insert
    case delete
}

struct DiffElement: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    let op: DiffOp
    let text: String

    init(id: UUID = UUID(), op: DiffOp, text: String) {
        self.id = id
        self.op = op
        self.text = text
    }
}

enum DiffHelper {
    
    /// Tokenizes a string into words, whitespaces, and punctuation to allow exact reconstruction.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        
        for char in text {
            if char.isWhitespace || char.isPunctuation {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
    
    /// Computes the word-level diff between two text blocks using standard LCS.
    static func computeWordDiff(old: String, new: String) -> [DiffElement] {
        let oldTokens = tokenize(old)
        let newTokens = tokenize(new)
        
        let n = oldTokens.count
        let m = newTokens.count
        
        // Handle simple edge cases quickly
        if n == 0 {
            return newTokens.map { DiffElement(op: .insert, text: $0) }
        }
        if m == 0 {
            return oldTokens.map { DiffElement(op: .delete, text: $0) }
        }
        
        // DP table for LCS
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        
        for i in 1...n {
            for j in 1...m {
                if oldTokens[i - 1] == newTokens[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        
        var result: [DiffElement] = []
        var i = n
        var j = m
        
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldTokens[i - 1] == newTokens[j - 1] {
                result.append(DiffElement(op: .equal, text: oldTokens[i - 1]))
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                result.append(DiffElement(op: .insert, text: newTokens[j - 1]))
                j -= 1
            } else {
                result.append(DiffElement(op: .delete, text: oldTokens[i - 1]))
                i -= 1
            }
        }
        
        return result.reversed()
    }
    
    /// Optimized two-stage diffing algorithm: paragraph-level first, then word-level for modified paragraphs.
    static func diff(old: String, new: String) -> [DiffElement] {
        // If the entire text is small (under 1500 characters), run word diff directly for accuracy
        if old.count < 1500 && new.count < 1500 {
            return computeWordDiff(old: old, new: new)
        }
        
        // Split by paragraphs
        let oldParagraphs = old.components(separatedBy: "\n")
        let newParagraphs = new.components(separatedBy: "\n")
        
        let n = oldParagraphs.count
        let m = newParagraphs.count
        
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        
        for i in 1...n {
            for j in 1...m {
                if oldParagraphs[i - 1] == newParagraphs[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        
        struct ParagraphDiff {
            let op: DiffOp
            let text: String
        }
        
        var rawDiffs: [ParagraphDiff] = []
        var i = n
        var j = m
        
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldParagraphs[i - 1] == newParagraphs[j - 1] {
                rawDiffs.append(ParagraphDiff(op: .equal, text: oldParagraphs[i - 1]))
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                rawDiffs.append(ParagraphDiff(op: .insert, text: newParagraphs[j - 1]))
                j -= 1
            } else {
                rawDiffs.append(ParagraphDiff(op: .delete, text: oldParagraphs[i - 1]))
                i -= 1
            }
        }
        
        let paragraphDiffs = Array(rawDiffs.reversed())
        var finalElements: [DiffElement] = []
        
        var idx = 0
        while idx < paragraphDiffs.count {
            let current = paragraphDiffs[idx]
            
            // Check if we have an adjacent delete followed by an insert, indicating a rewrite
            if idx + 1 < paragraphDiffs.count &&
               current.op == .delete &&
               paragraphDiffs[idx + 1].op == .insert {
                
                let deletedText = current.text
                let insertedText = paragraphDiffs[idx + 1].text
                
                // Perform token-level word diff on this specific paragraph pairing
                let subDiff = computeWordDiff(old: deletedText, new: insertedText)
                finalElements.append(contentsOf: subDiff)
                
                // Add a newline spacer if not at the end of the text
                if idx + 2 < paragraphDiffs.count {
                    finalElements.append(DiffElement(op: .equal, text: "\n"))
                }
                idx += 2
            } else {
                // Otherwise, output as a simple paragraph block
                let op = current.op
                let text = current.text
                
                if op == .equal {
                    finalElements.append(DiffElement(op: .equal, text: text))
                } else if op == .delete {
                    let words = tokenize(text)
                    finalElements.append(contentsOf: words.map { DiffElement(op: .delete, text: $0) })
                } else if op == .insert {
                    let words = tokenize(text)
                    finalElements.append(contentsOf: words.map { DiffElement(op: .insert, text: $0) })
                }
                
                // Add newline spacer if not at the end
                if idx + 1 < paragraphDiffs.count {
                    finalElements.append(DiffElement(op: .equal, text: "\n"))
                }
                idx += 1
            }
        }
        
        return finalElements
    }
}
