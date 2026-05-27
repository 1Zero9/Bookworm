import Foundation
import AppKit
import SwiftUI
import Observation
import UniformTypeIdentifiers

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
    var imageManifest: [ImageManifestEntry] = []
    var lastSavedAt: Date? = nil
    var subplots: [Subplot] = []
    var plotBeats: [PlotBeat] = []
    var formatMode: BookFormatMode = .novel

    @ObservationIgnored private var autoSaveTimer: Timer?

    init() {
        let first = Chapter(title: "Prologue", order: 0)
        self.chapters = [first]
        self.selectedChapterID = first.id
        let defaultSubplot = Subplot(name: "Main Plot", colorHex: "#3DBFB8", order: 0)
        self.subplots = [defaultSubplot]
        ImageManager.shared.ensureMediaDirectoryExists()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            guard let self, NSApp.isActive, self.fileURL != nil else { return }
            self.save()
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    func addWorldCharacter() {
        let ch = WorldCharacter(name: "New Character", order: worldCharacters.count, kind: .character)
        worldCharacters.append(ch)
    }

    func addWorldThing() {
        let t = WorldCharacter(name: "New Entry", order: worldCharacters.count, kind: .thing)
        worldCharacters.append(t)
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

    func exportMarkdownFolder() {
        let panel = NSSavePanel()
        panel.title = "Export Manuscript as Markdown"
        panel.nameFieldStringValue = markdownExportFolderName
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try writeMarkdownExport(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            showAlert("Could not export Markdown: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func performSave(to url: URL) {
        do {
            try createBackupIfNeeded(for: url)
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

    private func createBackupIfNeeded(for url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }

        let backupDir = url.deletingLastPathComponent().appendingPathComponent("Bookworm Backups", isDirectory: true)
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let baseName = url.deletingPathExtension().lastPathComponent
        let timestamp = Self.backupTimestampFormatter.string(from: Date())
        let backupURL = backupDir.appendingPathComponent("\(baseName) - \(timestamp).bookworm")

        try fm.copyItem(at: url, to: backupURL)
        try pruneBackups(in: backupDir, baseName: baseName, keeping: 25)
    }

    private func pruneBackups(in backupDir: URL, baseName: String, keeping limit: Int) throws {
        let fm = FileManager.default
        let backups = try fm.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter {
            $0.pathExtension == "bookworm"
            && $0.deletingPathExtension().lastPathComponent.hasPrefix("\(baseName) - ")
        }
        .sorted {
            let left = ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            let right = ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
            return left > right
        }

        for oldBackup in backups.dropFirst(limit) {
            try fm.removeItem(at: oldBackup)
        }
    }

    private func writeMarkdownExport(to folderURL: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let info = """
        # \(markdownTitle)

        Author: \(author.isEmpty ? "Unknown" : author)
        Chapters: \(chapters.count)
        Words: \(totalWordCount)
        Exported: \(Self.exportTimestampFormatter.string(from: Date()))

        This folder is a portable Markdown export. Keep the `.bookworm` file as the editable Bookworm source.
        """
        try info.write(
            to: folderURL.appendingPathComponent("00 - Book Info.md"),
            atomically: true,
            encoding: .utf8
        )

        for (index, chapter) in chapters.sorted(by: { $0.order < $1.order }).enumerated() {
            let number = String(format: "%03d", index + 1)
            let filename = "\(number) - \(Self.safeFilename(chapter.title)).md"
            let body = """
            # \(chapter.title)

            \(chapter.rawText)
            """
            try body.write(
                to: folderURL.appendingPathComponent(filename),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    private var markdownExportFolderName: String {
        "\(Self.safeFilename(title.isEmpty ? "Untitled Novel" : title)) Markdown"
    }

    private var markdownTitle: String {
        title.isEmpty ? "Untitled Novel" : title
    }

    private var totalWordCount: Int {
        chapters.reduce(0) {
            $0 + $1.rawText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        }
    }

    private static let backupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()

    private static let exportTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static func safeFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = value
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(80))
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
    var synopsis: String = ""
    var narrationScript: String = ""
    var images: [BookImage] = []
    var order: Int
    var status: ChapterStatus = .draft
    var versions: [DraftVersion] = []

    var annotations: [Annotation] = []

    var tensionScore: Double = 5.0
    var pacingSummary: String = ""

    init(id: UUID = UUID(), title: String, order: Int) {
        self.id = id
        self.title = title
        self.order = order
    }
}

// MARK: - Book Format Mode
enum BookFormatMode: String, Codable, CaseIterable, Identifiable {
    case novel = "Novel / Manuscript"
    case email = "Email / Correspondence"
    case letter = "Vintage Letter"
    case essay = "Standard Essay"
    case proposal = "Project Proposal"
    
    var id: String { self.rawValue }
    var icon: String {
        switch self {
        case .novel: return "book.closed"
        case .email: return "envelope"
        case .letter: return "quill"
        case .essay: return "doc.text"
        case .proposal: return "briefcase"
        }
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
