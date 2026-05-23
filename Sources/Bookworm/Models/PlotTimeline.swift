import Foundation
import Observation
import SwiftUI

@Observable
final class Subplot: Identifiable {
    let id: UUID
    var name: String
    var colorHex: String
    var order: Int

    init(id: UUID = UUID(), name: String, colorHex: String = "#3DBFB8", order: Int) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.order = order
    }
}

@Observable
final class PlotBeat: Identifiable {
    let id: UUID
    var title: String
    var summary: String
    var subplotID: UUID
    var chapterID: UUID
    var characterIDs: [UUID]

    init(id: UUID = UUID(), title: String, summary: String = "", subplotID: UUID, chapterID: UUID, characterIDs: [UUID] = []) {
        self.id = id
        self.title = title
        self.summary = summary
        self.subplotID = subplotID
        self.chapterID = chapterID
        self.characterIDs = characterIDs
    }
}

// MARK: - Serializable Files

struct SubplotFile: Codable {
    var id: UUID
    var name: String
    var colorHex: String
    var order: Int
}

struct PlotBeatFile: Codable {
    var id: UUID
    var title: String
    var summary: String
    var subplotID: UUID
    var chapterID: UUID
    var characterIDs: [UUID]
}

extension Subplot {
    func toFile() -> SubplotFile {
        SubplotFile(id: id, name: name, colorHex: colorHex, order: order)
    }

    convenience init(from file: SubplotFile) {
        self.init(id: file.id, name: file.name, colorHex: file.colorHex, order: file.order)
    }
}

extension PlotBeat {
    func toFile() -> PlotBeatFile {
        PlotBeatFile(id: id, title: title, summary: summary, subplotID: subplotID, chapterID: chapterID, characterIDs: characterIDs)
    }

    convenience init(from file: PlotBeatFile) {
        self.init(id: file.id, title: file.title, summary: file.summary, subplotID: file.subplotID, chapterID: file.chapterID, characterIDs: file.characterIDs)
    }
}
