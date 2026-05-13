import Foundation
import Observation
import SwiftUI

@Observable
final class CoreLedger {
    var genre:              String = ""
    var tone:               String = ""
    var spellingConvention: String = "UK English"
    var techOrMagicSystem:  String = ""
    var hardRules:          String = ""
    var styleNotes:         String = ""
}

enum WorldEntityKind: String, Codable, CaseIterable {
    case character = "Character"
    case thing     = "Thing"

    var listIcon: String {
        switch self {
        case .character: return "person.circle"
        case .thing:     return "mappin.circle"
        }
    }
}

struct CharacterStat: Identifiable, Codable {
    var id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id; self.key = key; self.value = value
    }
}

@Observable
final class WorldCharacter: Identifiable {
    let id: UUID
    var name:                 String
    var physicalDescription:  String = ""
    var psychologicalProfile: String = ""
    var personalVoice:        String = ""
    var notes:                String = ""
    var order:                Int
    var kind:                 WorldEntityKind = .character
    var portraitData:         Data? = nil
    var imageRef:             String? = nil
    var stats:                [CharacterStat] = []

    init(id: UUID = UUID(), name: String, order: Int, kind: WorldEntityKind = .character) {
        self.id = id; self.name = name; self.order = order; self.kind = kind
    }
}

// MARK: - Relationship arc map

enum RelationshipType: String, Codable, CaseIterable {
    case ally      = "Ally"
    case enemy     = "Enemy"
    case romantic  = "Romantic"
    case family    = "Family"
    case rival     = "Rival"
    case mentor    = "Mentor"
    case neutral   = "Neutral"

    var color: Color {
        switch self {
        case .ally:     return Color(hex: "#22C55E")
        case .enemy:    return Color(hex: "#EF4444")
        case .romantic: return Color(hex: "#EC4899")
        case .family:   return Color(hex: "#F59E0B")
        case .rival:    return Color(hex: "#FB923C")
        case .mentor:   return Color(hex: "#3DBFB8")
        case .neutral:  return Color(hex: "#94A3B8")
        }
    }
}

@Observable
final class CharacterRelationship: Identifiable {
    let id: UUID
    var fromID: UUID
    var toID: UUID
    var label: String
    var type: RelationshipType
    var chapterIntroduced: Int?

    init(id: UUID = UUID(), fromID: UUID, toID: UUID,
         label: String = "", type: RelationshipType = .neutral,
         chapterIntroduced: Int? = nil) {
        self.id = id; self.fromID = fromID; self.toID = toID
        self.label = label; self.type = type
        self.chapterIntroduced = chapterIntroduced
    }
}
