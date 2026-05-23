import Foundation
import AppKit
import CoreGraphics

// MARK: - File format

struct BookFile: Codable {
    var version: Int = 3
    var title: String
    var author: String
    var chapters: [ChapterFile]
    var coverImageData: Data?
    var selectedChapterID: UUID?
    // v2: World Bible (optional so older files decode without error)
    var coreLedger: CoreLedgerFile?
    var worldCharacters: [WorldCharacterFile]?
    // v3: Relationship arc map
    var relationships: [RelationshipFile]?
    var worldMapPositions: [MapPositionEntry]?
    // v4: Annotation archives
    var annotationArchives: [AnnotationArchive]?
    // v5: Image manifest for external media references
    var imageManifest: [ImageManifestEntry]?
    // v6: Plot timeline & subplots
    var subplots: [SubplotFile]?
    var plotBeats: [PlotBeatFile]?
    var formatMode: String?
}

struct RelationshipFile: Codable {
    var id: UUID
    var fromID: UUID
    var toID: UUID
    var fromName: String?   // human-readable — lets AI tools reference characters by name
    var toName: String?
    var label: String
    var type: String
    var chapterIntroduced: Int?
}

struct MapPositionEntry: Codable {
    var characterID: UUID
    var x: Double
    var y: Double
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
    var biography:            String?  // nil in files saved before v2.3
    var physicalDescription:  String
    var psychologicalProfile: String
    var personalVoice:        String
    var sensoryAnchors:       String?  // nil in files saved before v2.3
    var notes:                String
    var order:                Int
    var kind:                 String?  // nil in files saved before v2.1 → defaults to "Character"
    var portraitData:         Data?
    var imageRef:             String?
    var stats:                [CharacterStat]? // nil in files saved before v2.2
    var voiceIdentifier:      String?
    var aliases:              String?
}

struct ChapterFile: Codable {
    var id: UUID
    var title: String
    var rawText: String
    var synopsis: String?
    var narrationScript: String
    var order: Int
    var images: [ImageFile]
    var status: String?
    var versions: [DraftVersion]?
    var tensionScore: Double?
    var pacingSummary: String?
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
            version: 3,
            title: title,
            author: author,
            chapters: chapters.map { $0.toFile() },
            coverImageData: coverImage?.nsImage.pngData(),
            selectedChapterID: selectedChapterID,
            coreLedger: coreLedger.toFile(),
            worldCharacters: worldCharacters.map { $0.toFile() },
            relationships: relationships.map { rel in
                RelationshipFile(
                    id: rel.id, fromID: rel.fromID, toID: rel.toID,
                    fromName: worldCharacters.first { $0.id == rel.fromID }?.name,
                    toName:   worldCharacters.first { $0.id == rel.toID   }?.name,
                    label: rel.label, type: rel.type.rawValue,
                    chapterIntroduced: rel.chapterIntroduced
                )
            },
            worldMapPositions: worldMapPositions.map { MapPositionEntry(characterID: $0.key, x: $0.value.x, y: $0.value.y) },
            annotationArchives: annotationArchives.isEmpty ? nil : annotationArchives,
            imageManifest: imageManifest.isEmpty ? nil : imageManifest,
            subplots: subplots.isEmpty ? nil : subplots.map { $0.toFile() },
            plotBeats: plotBeats.isEmpty ? nil : plotBeats.map { $0.toFile() },
            formatMode: formatMode.rawValue
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
        relationships = (file.relationships ?? []).map { CharacterRelationship(from: $0) }
        worldMapPositions = Dictionary(
            uniqueKeysWithValues: (file.worldMapPositions ?? []).map { ($0.characterID, CGPoint(x: $0.x, y: $0.y)) }
        )
        annotationArchives = file.annotationArchives ?? []
        imageManifest = file.imageManifest ?? []
        ImageManager.shared.loadManifest(imageManifest)
        
        subplots = file.subplots?.map { Subplot(from: $0) } ?? [Subplot(name: "Main Plot", colorHex: "#3DBFB8", order: 0)]
        plotBeats = file.plotBeats?.map { PlotBeat(from: $0) } ?? []
        if let fmRaw = file.formatMode, let fm = BookFormatMode(rawValue: fmRaw) {
            formatMode = fm
        } else {
            formatMode = .novel
        }
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
        WorldCharacterFile(id: id, name: name,
                           biography: biography.isEmpty ? nil : biography,
                           physicalDescription: physicalDescription,
                           psychologicalProfile: psychologicalProfile,
                           personalVoice: personalVoice,
                           sensoryAnchors: sensoryAnchors.isEmpty ? nil : sensoryAnchors,
                           notes: notes, order: order,
                           kind: kind.rawValue,
                           portraitData: portraitData,
                           imageRef: imageRef,
                           stats: stats.isEmpty ? nil : stats,
                           voiceIdentifier: voiceIdentifier.isEmpty ? nil : voiceIdentifier,
                           aliases: aliases.isEmpty ? nil : aliases)
    }
    convenience init(from f: WorldCharacterFile) {
        let k = WorldEntityKind(rawValue: f.kind ?? "Character") ?? .character
        self.init(id: f.id, name: f.name, order: f.order, kind: k)
        biography            = f.biography ?? ""
        physicalDescription  = f.physicalDescription
        psychologicalProfile = f.psychologicalProfile
        personalVoice        = f.personalVoice
        sensoryAnchors       = f.sensoryAnchors ?? ""
        notes                = f.notes
        portraitData         = f.portraitData
        imageRef             = f.imageRef
        stats                = f.stats ?? []
        voiceIdentifier      = f.voiceIdentifier ?? ""
        aliases              = f.aliases ?? ""
    }
}

extension Chapter {
    func toFile() -> ChapterFile {
        ChapterFile(
            id: id,
            title: title,
            rawText: rawText,
            synopsis: synopsis.isEmpty ? nil : synopsis,
            narrationScript: narrationScript,
            order: order,
            images: images.map { $0.toFile() },
            status: status.rawValue,
            versions: versions.isEmpty ? nil : versions,
            tensionScore: tensionScore,
            pacingSummary: pacingSummary.isEmpty ? nil : pacingSummary
        )
    }

    convenience init(from file: ChapterFile) {
        self.init(id: file.id, title: file.title, order: file.order)
        rawText = file.rawText
        synopsis = file.synopsis ?? ""
        narrationScript = file.narrationScript
        images = file.images.compactMap { BookImage(from: $0) }
        if let s = file.status { status = ChapterStatus(rawValue: s) ?? .draft }
        versions = file.versions ?? []
        tensionScore = file.tensionScore ?? 5.0
        pacingSummary = file.pacingSummary ?? ""
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

extension CharacterRelationship {
    func toFile(fromName: String? = nil, toName: String? = nil) -> RelationshipFile {
        RelationshipFile(id: id, fromID: fromID, toID: toID,
                         fromName: fromName, toName: toName,
                         label: label, type: type.rawValue,
                         chapterIntroduced: chapterIntroduced)
    }
    convenience init(from f: RelationshipFile) {
        self.init(id: f.id, fromID: f.fromID, toID: f.toID,
                  label: f.label,
                  type: RelationshipType(rawValue: f.type) ?? .neutral,
                  chapterIntroduced: f.chapterIntroduced)
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
