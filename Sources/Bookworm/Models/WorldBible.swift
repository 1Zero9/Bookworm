import Foundation
import Observation

@Observable
final class CoreLedger {
    var genre:              String = ""
    var tone:               String = ""
    var spellingConvention: String = "UK English"
    var techOrMagicSystem:  String = ""
    var hardRules:          String = ""
    var styleNotes:         String = ""
}

@Observable
final class WorldCharacter: Identifiable {
    let id: UUID
    var name:                 String
    var physicalDescription:  String = ""
    var psychologicalProfile: String = ""
    var personalVoice:        String = ""
    var notes:                String = ""
    var order: Int

    init(id: UUID = UUID(), name: String, order: Int) {
        self.id = id; self.name = name; self.order = order
    }
}
