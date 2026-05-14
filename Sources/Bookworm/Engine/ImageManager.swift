import AppKit
import Foundation

// MARK: - Manifest entry

/// One row in the `images` array of a WorldBible JSON export.
/// `id` may be any stable string (UUID, slug, etc.).
/// `fileName` is the bare filename inside ~/Documents/Bookworm/Media/.
struct ImageManifestEntry: Codable, Identifiable, Hashable {
    var id:       String
    var fileName: String
    var category: String   // "characters" | "things"
}

// MARK: - Image Manager

/// Resolves external image references from ~/Documents/Bookworm/Media/.
///
/// Usage flow:
///   1. The WorldBible JSON contains an `images` array of ImageManifestEntry values.
///   2. On import, call ImageManager.shared.loadManifest(_:).
///   3. Each WorldCharacter carries an optional `imageRef` (manifest ID or bare filename).
///   4. Call WorldCharacter.resolvedImage — it consults the manager automatically.
///
/// The manager tries the ref as a manifest ID first, then as a bare filename,
/// so JSON that skips the manifest and just sets `imageRef: "aria.jpg"` still works.
final class ImageManager {
    static let shared = ImageManager()
    private init() {}

    // MARK: Media directory

    static var mediaDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Bookworm/Media")
    }

    // MARK: State

    private var byID:       [String: ImageManifestEntry] = [:]
    private var byFileName: [String: ImageManifestEntry] = [:]
    private var cache:      [String: NSImage]            = [:]

    // User-selected media folder (persisted so it survives restarts).
    var customMediaDirectory: URL? {
        get {
            UserDefaults.standard.string(forKey: "bw.customMediaDir")
                .map { URL(fileURLWithPath: $0) }
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.path, forKey: "bw.customMediaDir")
            } else {
                UserDefaults.standard.removeObject(forKey: "bw.customMediaDir")
            }
            cache.removeAll()
        }
    }

    // MARK: Manifest

    func loadManifest(_ entries: [ImageManifestEntry]) {
        byID       = entries.reduce(into: [:]) { $0[$1.id]       = $1 }
        byFileName = entries.reduce(into: [:]) { $0[$1.fileName] = $1 }
        cache.removeAll()   // old cached images may now be stale
    }

    // MARK: Resolution

    /// Returns the NSImage for `ref`, or a system-symbol fallback.
    /// `ref` may be a manifest ID *or* a bare filename — both resolve correctly.
    func image(forRef ref: String, kind: WorldEntityKind = .character) -> NSImage {
        if let cached = cache[ref] { return cached }

        let fileName = byID[ref]?.fileName       // ref is a manifest ID
                    ?? byFileName[ref]?.fileName  // ref is already a fileName in the manifest
                    ?? ref                        // ref IS the filename — used directly

        let searchRoots: [URL] = [Self.mediaDirectory, customMediaDirectory].compactMap { $0 }
        for root in searchRoots {
            let url = root.appendingPathComponent(fileName)
            if let img = NSImage(contentsOf: url) {
                cache[ref] = img
                return img
            }
        }
        return fallback(for: kind)
    }

    /// System-symbol placeholder when no image file is found.
    func fallback(for kind: WorldEntityKind) -> NSImage {
        let symbol = kind == .character ? "person.fill" : "mappin.and.ellipse"
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage()
    }

    func clearCache() { cache.removeAll() }

    /// Creates ~/Documents/Bookworm/Media/ if it doesn't already exist.
    func ensureMediaDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: Self.mediaDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Auto-match

    /// For every character/thing that has no imageRef and no embedded portraitData,
    /// scans the custom media directory and assigns imageRef to the first file whose
    /// name contains a meaningful word from the entity's name.
    ///
    /// Example: "Harlan Voss" → finds "voss_v1.png" → sets imageRef = "voss_v1.png"
    @discardableResult
    func autoMatch(characters: [WorldCharacter]) -> Int {
        guard let mediaDir = customMediaDirectory else { return 0 }
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "webp"]
        guard let allFiles = try? FileManager.default.contentsOfDirectory(atPath: mediaDir.path) else { return 0 }
        let imageFiles = allFiles.filter { imageExts.contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }
        guard !imageFiles.isEmpty else { return 0 }

        var matched = 0
        for character in characters {
            guard character.imageRef == nil || character.imageRef!.isEmpty,
                  character.portraitData == nil else { continue }

            // Build search words: strip parenthesised suffixes, drop short/noise words
            let cleaned = character.name
                .replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
                .lowercased()
            let words = cleaned
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 && $0 != "the" && $0 != "and" }

            guard !words.isEmpty else { continue }

            for file in imageFiles {
                let fileLower = file.lowercased()
                if words.contains(where: { fileLower.contains($0) }) {
                    character.imageRef = file
                    cache.removeValue(forKey: file)
                    matched += 1
                    break
                }
            }
        }
        return matched
    }
}

// MARK: - WorldCharacter convenience

extension WorldCharacter {
    /// Unified image source in priority order:
    ///   1. External file referenced by `imageRef` (resolved via ImageManager)
    ///   2. Embedded `portraitData` blob stored in the .bookworm file
    ///   3. System-symbol fallback — never returns nil, UI never breaks
    var resolvedImage: NSImage {
        if let ref = imageRef, !ref.isEmpty {
            return ImageManager.shared.image(forRef: ref, kind: kind)
        }
        if let data = portraitData, let img = NSImage(data: data) { return img }
        return ImageManager.shared.fallback(for: kind)
    }

    /// True when any image source (external ref or embedded data) is available.
    var hasImage: Bool {
        imageRef.map { !$0.isEmpty } ?? false || portraitData != nil
    }
}
