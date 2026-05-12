import Foundation
import AppKit

// MARK: - File format

struct BookFile: Codable {
    var version: Int = 2
    var title: String
    var author: String
    var chapters: [ChapterFile]
    var coverImageData: Data?
    var selectedChapterID: UUID?
    // v2: World Bible (optional so older files decode without error)
    var coreLedger: CoreLedgerFile?
    var worldCharacters: [WorldCharacterFile]?
}

struct CoreLedgerFile: Codable {
    var genre:              String
    var tone:               String
    var spellingConvention: String
    var techOrMagicSystem:  String
    var hardRules:          String
    var styleNotes:         String
}

struct WorldCharacterFile: Codable {
    var id:                   UUID
    var name:                 String
    var physicalDescription:  String
    var psychologicalProfile: String
    var personalVoice:        String
    var notes:                String
    var order:                Int
}

struct ChapterFile: Codable {
    var id: UUID
    var title: String
    var rawText: String
    var narrationScript: String
    var order: Int
    var images: [ImageFile]
}

struct ImageFile: Codable {
    var id: UUID
    var data: Data
    var caption: String
    var placement: String
}

// MARK: - Book serialisation

extension Book {
    func toFile() -> BookFile {
        BookFile(
            title: title,
            author: author,
            chapters: chapters.map { $0.toFile() },
            coverImageData: coverImage?.nsImage.pngData(),
            selectedChapterID: selectedChapterID,
            coreLedger: coreLedger.toFile(),
            worldCharacters: worldCharacters.map { $0.toFile() }
        )
    }

    func apply(file: BookFile) {
        title = file.title
        author = file.author
        chapters = file.chapters.map { Chapter(from: $0) }
        if let data = file.coverImageData, let img = NSImage(data: data) {
            coverImage = BookImage(nsImage: img, placement: .cover)
        } else {
            coverImage = nil
        }
        selectedChapterID = file.selectedChapterID ?? chapters.first?.id
        if let lf = file.coreLedger { coreLedger.apply(lf) }
        worldCharacters = file.worldCharacters?.map { WorldCharacter(from: $0) } ?? []
    }
}

extension CoreLedger {
    func toFile() -> CoreLedgerFile {
        CoreLedgerFile(genre: genre, tone: tone, spellingConvention: spellingConvention,
                       techOrMagicSystem: techOrMagicSystem, hardRules: hardRules, styleNotes: styleNotes)
    }
    func apply(_ f: CoreLedgerFile) {
        genre = f.genre; tone = f.tone; spellingConvention = f.spellingConvention
        techOrMagicSystem = f.techOrMagicSystem; hardRules = f.hardRules; styleNotes = f.styleNotes
    }
}

extension WorldCharacter {
    func toFile() -> WorldCharacterFile {
        WorldCharacterFile(id: id, name: name, physicalDescription: physicalDescription,
                           psychologicalProfile: psychologicalProfile, personalVoice: personalVoice,
                           notes: notes, order: order)
    }
    convenience init(from f: WorldCharacterFile) {
        self.init(id: f.id, name: f.name, order: f.order)
        physicalDescription  = f.physicalDescription
        psychologicalProfile = f.psychologicalProfile
        personalVoice        = f.personalVoice
        notes                = f.notes
    }
}

extension Chapter {
    func toFile() -> ChapterFile {
        ChapterFile(
            id: id,
            title: title,
            rawText: rawText,
            narrationScript: narrationScript,
            order: order,
            images: images.map { $0.toFile() }
        )
    }

    convenience init(from file: ChapterFile) {
        self.init(id: file.id, title: file.title, order: file.order)
        rawText = file.rawText
        narrationScript = file.narrationScript
        images = file.images.compactMap { BookImage(from: $0) }
    }
}

extension BookImage {
    func toFile() -> ImageFile {
        ImageFile(id: id, data: nsImage.pngData() ?? Data(),
                  caption: caption, placement: placement.rawValue)
    }

    init?(from file: ImageFile) {
        guard let img = NSImage(data: file.data) else { return nil }
        self.init(id: file.id, nsImage: img, caption: file.caption,
                  placement: Placement(rawValue: file.placement) ?? .inline)
    }
}

// MARK: - NSImage helpers

extension NSImage {
    func pngData() -> Data? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
