import Foundation
import AppKit
import SwiftUI
import Observation

@Observable
final class Book {
    var title: String = "Untitled Novel"
    var author: String = ""
    var chapters: [Chapter]
    var coverImage: BookImage?
    var selectedChapterID: UUID?
    // Set by scroll tracking (not persisted). Drives sidebar highlight independently of selection.
    var visibleChapterID: UUID?
    var fileURL: URL?
    var coreLedger = CoreLedger()
    var worldCharacters: [WorldCharacter] = []
    var relationships: [CharacterRelationship] = []
    var worldMapPositions: [UUID: CGPoint] = [:]
    var annotationArchives: [AnnotationArchive] = []
    var lastSavedAt: Date? = nil

    @ObservationIgnored private var autoSaveTimer: Timer?

    init() {
        let first = Chapter(title: "Prologue", order: 0)
        self.chapters = [first]
        self.selectedChapterID = first.id
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            guard let self, NSApp.isActive, self.fileURL != nil else { return }
            self.save()
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    func addWorldCharacter() {
        let ch = WorldCharacter(name: "New Character", order: worldCharacters.count)
        worldCharacters.append(ch)
    }

    var selectedChapter: Chapter? {
        guard let id = selectedChapterID else { return nil }
        return chapters.first { $0.id == id }
    }

    func addChapter() {
        let names = ["The Adventure Begins", "A New Discovery", "Into the Unknown",
                     "Secrets Revealed", "The Final Battle", "A New Dawn"]
        let name = chapters.count < names.count
            ? names[chapters.count]
            : "Chapter \(chapters.count + 1)"
        let ch = Chapter(title: name, order: chapters.count)
        chapters.append(ch)
        selectedChapterID = ch.id
    }

    func deleteChapter(_ chapter: Chapter) {
        chapters.removeAll { $0.id == chapter.id }
        selectedChapterID = chapters.last?.id
    }

    func moveChapters(from source: IndexSet, to destination: Int) {
        chapters.move(fromOffsets: source, toOffset: destination)
        for (i, ch) in chapters.enumerated() { ch.order = i }
    }

    // MARK: - Save / Load

    func save() {
        guard let url = fileURL else { saveAs(); return }
        performSave(to: url)
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.title = "Save Bookworm File"
        panel.allowedContentTypes = [.init(filenameExtension: "bookworm")!]
        panel.nameFieldStringValue = title.isEmpty ? "My Novel" : title
        if let icloud = iCloudDriveURL {
            panel.directoryURL = icloud
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        fileURL = url
        performSave(to: url)
    }

    func open() {
        let panel = NSOpenPanel()
        panel.title = "Open Bookworm File"
        panel.allowedContentTypes = [.init(filenameExtension: "bookworm")!]
        panel.allowsMultipleSelection = false
        if let icloud = iCloudDriveURL { panel.directoryURL = icloud }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(from: url)
    }

    func load(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(BookFile.self, from: data)
            apply(file: file)
            fileURL = url
            RecentBooksStore.shared.add(url: url, title: file.title, author: file.author)
        } catch {
            showAlert("Could not open file: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func performSave(to url: URL) {
        do {
            let data = try JSONEncoder().encode(toFile())
            try data.write(to: url, options: .atomic)
            lastSavedAt = Date()
            RecentBooksStore.shared.add(url: url, title: title, author: author)
        } catch {
            showAlert("Could not save: \(error.localizedDescription)")
        }
    }

    private var iCloudDriveURL: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.runModal()
        }
    }
}

enum ChapterStatus: String, CaseIterable, Codable {
    case draft      = "Draft"
    case inProgress = "In Progress"
    case needsWork  = "Needs Work"
    case complete   = "Complete"

    var color: Color {
        switch self {
        case .draft:      return Color(NSColor.tertiaryLabelColor)
        case .inProgress: return Color(NSColor.systemBlue)
        case .needsWork:  return Color(NSColor.systemOrange)
        case .complete:   return Color(NSColor.systemGreen)
        }
    }

    var icon: String {
        switch self {
        case .draft:      return "circle"
        case .inProgress: return "pencil.circle.fill"
        case .needsWork:  return "exclamationmark.circle.fill"
        case .complete:   return "checkmark.circle.fill"
        }
    }
}

@Observable
final class Chapter: Identifiable {
    let id: UUID
    var title: String
    var rawText: String = ""
    var narrationScript: String = ""
    var images: [BookImage] = []
    var order: Int
    var status: ChapterStatus = .draft

    var annotations: [Annotation] = []

    init(id: UUID = UUID(), title: String, order: Int) {
        self.id = id
        self.title = title
        self.order = order
    }
}

struct BookImage: Identifiable {
    let id: UUID
    var nsImage: NSImage
    var caption: String
    var placement: Placement

    init(id: UUID = UUID(), nsImage: NSImage, caption: String = "", placement: Placement = .inline) {
        self.id = id
        self.nsImage = nsImage
        self.caption = caption
        self.placement = placement
    }

    enum Placement: String, CaseIterable, Codable {
        case cover = "Cover"
        case chapterHeader = "Chapter Header"
        case inline = "Inline"
        case fullPage = "Full Page"
    }
}
