import Foundation

struct DraftVersion: Codable, Identifiable, Hashable {
    var id: UUID
    var timestamp: Date
    var text: String
    var description: String

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, description: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.description = description
    }
}
