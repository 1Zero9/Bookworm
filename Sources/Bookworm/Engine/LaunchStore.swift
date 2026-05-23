import Foundation
import SwiftUI
import AppKit

enum LaunchMode: String, Codable {
    case launcher
    case editor
}

final class LaunchStore: ObservableObject {
    static let shared = LaunchStore()
    
    @Published var activeMode: LaunchMode = .launcher
    @Published var isSandboxActive: Bool = false
    @Published var currentBook: Book = Book()
    
    var primaryBookBackup: Book? = nil
    private var primaryBookURLBackup: URL? = nil
    
    private init() {}
    
    /// Bootstraps a new book based on a specialized template and launches the editor.
    func createNewBook(format: BookFormatMode) -> Book {
        let newBook = Book()
        newBook.formatMode = format
        
        switch format {
        case .novel:
            newBook.title = "Untitled Novel"
            // Default novel structure is already initialized in Book.init()
            
        case .email:
            newBook.title = "New Email Draft"
            newBook.chapters = [
                Chapter(title: "Subject: [Your Subject]", order: 0)
            ]
            newBook.selectedChapterID = newBook.chapters.first?.id
            newBook.chapters.first?.rawText = "To: \nSubject: \n\nDear [Name],\n\n"
            
        case .letter:
            newBook.title = "New Letter Draft"
            newBook.chapters = [
                Chapter(title: "Date: \(formattedCurrentDate())", order: 0)
            ]
            newBook.selectedChapterID = newBook.chapters.first?.id
            newBook.chapters.first?.rawText = "Dearest [Name],\n\nWrite your letter here...\n\nSincerely,\n[Your Name]"
            
        case .essay:
            newBook.title = "Academic Essay"
            newBook.chapters = [
                Chapter(title: "Introduction", order: 0),
                Chapter(title: "Body Paragraph 1", order: 1),
                Chapter(title: "Conclusion", order: 2)
            ]
            newBook.selectedChapterID = newBook.chapters.first?.id
            newBook.chapters.first?.rawText = "\tStart typing your academic double-spaced essay here..."
            
        case .proposal:
            newBook.title = "Project Proposal"
            newBook.chapters = [
                Chapter(title: "Executive Summary", order: 0),
                Chapter(title: "Project Scope & Goals", order: 1),
                Chapter(title: "Technical Approach", order: 2),
                Chapter(title: "Budget & Resources", order: 3),
                Chapter(title: "Timeline & Deliverables", order: 4)
            ]
            newBook.selectedChapterID = newBook.chapters.first?.id
            newBook.chapters.first?.rawText = "Executive Summary\n\nProvide a high-level overview of the proposed project..."
        }
        
        self.currentBook = newBook
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.activeMode = .editor
        }
        return newBook
    }
    
    /// Starts a completely clean editor instance without modifying the parent book, designed to beat writer's block.
    func startScratchCanvas(parentBook: Book) {
        // Backup primary book references
        self.primaryBookBackup = parentBook
        self.primaryBookURLBackup = parentBook.fileURL
        
        let sandboxBook = Book()
        sandboxBook.formatMode = parentBook.formatMode
        sandboxBook.title = "Scratch Canvas"
        
        let scratchChapter = Chapter(title: "Free Draft", order: 0)
        scratchChapter.rawText = ""
        sandboxBook.chapters = [scratchChapter]
        sandboxBook.selectedChapterID = scratchChapter.id
        
        self.currentBook = sandboxBook
        self.isSandboxActive = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.activeMode = .editor
        }
    }
    
    /// Merges scratch canvas text into a specific chapter of the primary book and returns to primary editor.
    func mergeScratchProse(to chapterID: UUID) {
        guard let primary = primaryBookBackup,
              let scratchText = currentBook.chapters.first?.rawText,
              !scratchText.isEmpty else {
            cancelSandbox()
            return
        }
        
        if let targetChapter = primary.chapters.first(where: { $0.id == chapterID }) {
            // Append with neat spacing
            if targetChapter.rawText.isEmpty {
                targetChapter.rawText = scratchText
            } else {
                targetChapter.rawText += "\n\n\(scratchText)"
            }
        }
        
        // Restore primary book
        self.currentBook = primary
        self.currentBook.fileURL = primaryBookURLBackup
        self.primaryBookBackup = nil
        self.primaryBookURLBackup = nil
        self.isSandboxActive = false
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.activeMode = .editor
        }
    }
    
    /// Abandons the current sandbox draft and returns to the primary book.
    func cancelSandbox() {
        if let primary = primaryBookBackup {
            self.currentBook = primary
            self.currentBook.fileURL = primaryBookURLBackup
        }
        self.primaryBookBackup = nil
        self.primaryBookURLBackup = nil
        self.isSandboxActive = false
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.activeMode = .editor
        }
    }
    
    /// Sets active editor book from local URL
    func loadBook(url: URL) {
        let loadedBook = Book()
        loadedBook.load(from: url)
        self.currentBook = loadedBook
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.activeMode = .editor
        }
    }
    
    /// Exits back to launcher
    func exitToLauncher() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.activeMode = .launcher
        }
    }
    
    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }
}
