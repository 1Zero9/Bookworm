import Foundation

struct RecentBook: Codable, Identifiable {
    let id: UUID
    let urlString: String
    let title: String
    let author: String
    let savedDate: Date

    var url: URL? { URL(string: urlString) }
    var exists: Bool { url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }
}

final class RecentBooksStore {
    static let shared = RecentBooksStore()
    private let key = "recentBooks_v2"
    private let maxCount = 20

    private(set) var recents: [RecentBook] = []

    private init() { load() }

    func add(url: URL, title: String, author: String) {
        var items = recents.filter { $0.urlString != url.absoluteString }
        items.insert(RecentBook(id: UUID(), urlString: url.absoluteString,
                                title: title, author: author, savedDate: Date()), at: 0)
        recents = Array(items.prefix(maxCount))
        persist()
    }

    func remove(_ book: RecentBook) {
        recents.removeAll { $0.id == book.id }
        persist()
    }

    var lastURL: URL? {
        recents.first(where: \.exists)?.url
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([RecentBook].self, from: data) else { return }
        recents = items
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(recents) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
