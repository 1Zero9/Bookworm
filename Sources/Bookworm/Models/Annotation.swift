import Foundation
import SwiftUI
import AppKit

struct Annotation: Identifiable {
    let id: UUID
    var start: Int      // NSString UTF-16 offset
    var end: Int
    var note: String
    var tag: AnnotationTag

    init(id: UUID = UUID(), start: Int, end: Int, note: String = "", tag: AnnotationTag = .note) {
        self.id = id; self.start = start; self.end = end; self.note = note; self.tag = tag
    }

    var nsRange: NSRange { NSRange(location: start, length: max(0, end - start)) }
}

// MARK: - Archive

struct AnnotationArchive: Identifiable, Codable {
    var id:           UUID    = UUID()
    var draftLabel:   String
    var chapterTitle: String
    var snippet:      String   // text at the time of archiving
    var note:         String
    var tag:          AnnotationTag
    var archivedAt:   Date
}

enum AnnotationTag: String, CaseIterable, Codable {
    case note   = "Note"
    case issue  = "Issue"
    case strong = "Strong"
    case query  = "Query"

    var nsColor: NSColor {
        switch self {
        case .note:   return .systemYellow.withAlphaComponent(0.42)
        case .issue:  return .systemRed.withAlphaComponent(0.30)
        case .strong: return .systemGreen.withAlphaComponent(0.30)
        case .query:  return .systemBlue.withAlphaComponent(0.28)
        }
    }

    var color: Color {
        switch self {
        case .note:   return .yellow
        case .issue:  return .red
        case .strong: return .green
        case .query:  return .blue
        }
    }

    var icon: String {
        switch self {
        case .note:   return "pencil"
        case .issue:  return "exclamationmark.triangle"
        case .strong: return "checkmark"
        case .query:  return "questionmark"
        }
    }
}
