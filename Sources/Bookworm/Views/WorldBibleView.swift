import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export package (strict, round-trips cleanly)

private struct WorldBiblePackage: Codable {
    var coreLedger: CoreLedgerFile
    var characters: [WorldCharacterFile]
    var relationships: [RelationshipFile]?
    var worldMapPositions: [MapPositionEntry]?
    var images: [ImageManifestEntry]?
    var schema: SchemaHints?

    struct SchemaHints: Codable {
        var relationshipTypes: [String]
        var instructions: String
        var exampleRelationship: ExampleRel

        struct ExampleRel: Codable {
            var fromName: String
            var toName: String
            var type: String
            var label: String
            var chapterIntroduced: Int
        }
    }
}

// MARK: - Flexible import (handles external/AI-generated JSON with different field names)

private struct FlexWorldBible: Decodable {

    struct FlexLedger: Decodable {
        let genre:              String?
        let tone:               String?
        let spellingConvention: String?
        let techOrMagicSystem:  String?
        let hardRules:          String?
        let styleNotes:         String?

        func toCoreFile() -> CoreLedgerFile {
            CoreLedgerFile(
                genre:              genre              ?? "",
                tone:               tone               ?? "",
                spellingConvention: spellingConvention ?? "UK English",
                techOrMagicSystem:  techOrMagicSystem  ?? "",
                hardRules:          hardRules          ?? "",
                styleNotes:         styleNotes         ?? ""
            )
        }
    }

    // Decodes stats whether stored as {"key": number} dict or [{id,key,value}] array
    enum FlexStats: Decodable {
        case dict([String: Double])
        case array([CharacterStat])

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let d = try? c.decode([String: Double].self) { self = .dict(d); return }
            self = .array((try? c.decode([CharacterStat].self)) ?? [])
        }

        var asCharacterStats: [CharacterStat] {
            switch self {
            case .dict(let d):
                return d.sorted { $0.key < $1.key }.map { k, v in
                    CharacterStat(key: k, value: v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v))
                }
            case .array(let a): return a
            }
        }
    }

    struct FlexCharacter: Decodable {
        // Bookworm native keys — id decoded as String so invalid UUIDs don't throw
        let idString:             String?
        let order:                Int?
        let physicalDescription:  String?
        let psychologicalProfile: String?
        let personalVoice:        String?
        let notes:                String?
        let biography:            String?
        let sensoryAnchors:       String?
        let imageRef:             String?
        let stats:                FlexStats?
        // External / AI-generated keys
        let name:              String?
        let role:              String?
        let traits:            String?
        let sensory_anchors:   String?
        let status:            String?
        let backstory:         String?
        let voice:             String?
        let description:       String?

        enum CodingKeys: String, CodingKey {
            case idString = "id"
            case order, name, role, traits, status, backstory, voice, description
            case physicalDescription, psychologicalProfile, personalVoice, notes
            case biography, sensoryAnchors, imageRef, stats
            case sensory_anchors = "sensory_anchors"
        }

        func toWorldCharacter(index: Int, kind: WorldEntityKind = .character) -> WorldCharacter {
            let uuid = idString.flatMap { UUID(uuidString: $0) } ?? UUID()
            let c = WorldCharacter(id: uuid, name: name ?? "Unnamed", order: order ?? index, kind: kind)
            c.biography            = biography ?? ""
            c.physicalDescription  = physicalDescription ?? description ?? ""
            c.psychologicalProfile = psychologicalProfile ?? traits ?? ""
            c.personalVoice        = personalVoice ?? voice ?? ""
            c.sensoryAnchors       = sensoryAnchors ?? sensory_anchors ?? ""
            c.imageRef             = imageRef
            if let s = stats { c.stats = s.asCharacterStats }
            var extra: [String] = []
            if let r = role    { extra.append("Role: \(r)") }
            if let s = status  { extra.append("Status: \(s)") }
            if let b = backstory { extra.append(b) }
            if let n = notes   { extra.append(n) }
            c.notes = extra.joined(separator: "\n")
            return c
        }
    }

    let coreLedger: FlexLedger?
    let characters: [FlexCharacter]?
    let things:     [FlexCharacter]?
    let images:     [ImageManifestEntry]?
    let relationships: [FlexRelationship]?

    struct FlexRelationship: Decodable {
        // Name-based (Gemini / human-authored)
        let from:     String?
        let to:       String?
        let fromName: String?
        let toName:   String?
        // UUID-based (app round-trip)
        let fromID:   String?
        let toID:     String?
        // Shared
        let label:    String?
        let type:     String?
        let chapterIntroduced: Int?

        func resolve(against characters: [WorldCharacter]) -> CharacterRelationship? {
            func find(_ nameHint: String?, _ idHint: String?) -> WorldCharacter? {
                if let s = idHint, let uuid = UUID(uuidString: s),
                   let c = characters.first(where: { $0.id == uuid }) { return c }
                let name = (nameHint ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                guard !name.isEmpty else { return nil }
                return characters.first { $0.name.lowercased() == name }
                    ?? characters.first { $0.name.lowercased().hasPrefix(name) }
            }
            guard let fc = find(fromName ?? from, fromID),
                  let tc = find(toName   ?? to,   toID),
                  fc.id != tc.id else { return nil }
            return CharacterRelationship(
                fromID: fc.id, toID: tc.id,
                label:  label ?? "",
                type:   RelationshipType(rawValue: type?.capitalized ?? "") ?? .neutral,
                chapterIntroduced: chapterIntroduced
            )
        }
    }
}

// MARK: - View

struct WorldBibleView: View {
    @Environment(Book.self) private var book
    @State private var tab: Tab = .coreLedger
    @State private var importError: String? = nil
    @State private var showImportError = false

    enum Tab { case coreLedger, characters, arcMap }

    var body: some View {
        @Bindable var book = book
        VStack(spacing: 0) {
            PanelHeader(
                step: "W",
                label: "WORLD BIBLE",
                subtitle: "genre, rules, people & places",
                accent: AppTheme.accentWorld
            ) {
                HStack(spacing: 4) {
                    WorldBibleTab(label: "Core Ledger", icon: "doc.text.fill",                         tab: .coreLedger, current: $tab)
                    WorldBibleTab(label: "Characters",  icon: "person.2.fill",                         tab: .characters,  current: $tab)
                    WorldBibleTab(label: "Arc Map",     icon: "point.3.connected.trianglepath.dotted", tab: .arcMap,      current: $tab)

                    Divider().frame(height: 16).padding(.horizontal, 2)

                    Button { importWorldBible() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down").font(.system(size: 10, weight: .medium))
                            Text("Import").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.accentWorld)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.accentWorld.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Import world bible from a JSON file")

                    Button { pickMediaFolder() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder").font(.system(size: 10, weight: .medium))
                            Text("Media…").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(ImageManager.shared.customMediaDirectory != nil
                                         ? AppTheme.accentNarrate : AppTheme.textSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.border.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help(ImageManager.shared.customMediaDirectory.map { "Media folder: \($0.path)\nClick to change" }
                          ?? "Set the folder containing character/thing images")

                    Button { exportWorldBible() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 10, weight: .medium))
                            Text("Export").font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.border.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Export world bible as a shareable template")
                }
            }

            Divider().background(AppTheme.border)

            switch tab {
            case .coreLedger: CoreLedgerForm(ledger: book.coreLedger)
            case .characters: CharacterVaultView(book: book)
            case .arcMap:     RelationshipMapView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK") {}
        } message: {
            Text(importError ?? "Could not read the file.")
        }
    }

    // MARK: - Export

    private func exportWorldBible() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let chars = book.worldCharacters
        let rels: [RelationshipFile] = book.relationships.map { rel in
            rel.toFile(
                fromName: chars.first { $0.id == rel.fromID }?.name,
                toName:   chars.first { $0.id == rel.toID   }?.name
            )
        }
        let positions = book.worldMapPositions.map { MapPositionEntry(characterID: $0.key, x: $0.value.x, y: $0.value.y) }
        let firstCharName  = chars.first?.name ?? "Character A"
        let secondCharName = chars.dropFirst().first?.name ?? "Character B"
        let hints = WorldBiblePackage.SchemaHints(
            relationshipTypes: RelationshipType.allCases.map { $0.rawValue },
            instructions: "Populate the 'relationships' array below. Use 'fromName' and 'toName' matching the character names exactly. 'type' must be one of the values in 'relationshipTypes'. 'label' is a short phrase e.g. 'old rivals', 'secretly in love'. 'chapterIntroduced' (integer) is optional — omit it if the relationship exists from the start. Multiple relationships between the same pair are allowed. 'worldMapPositions' can be omitted; nodes auto-arrange.",
            exampleRelationship: .init(
                fromName: firstCharName,
                toName:   secondCharName,
                type:     "Ally",
                label:    "brief description e.g. childhood friends",
                chapterIntroduced: 1
            )
        )
        let package = WorldBiblePackage(
            coreLedger: book.coreLedger.toFile(),
            characters: chars.map { $0.toFile() },
            relationships: rels,
            worldMapPositions: positions,
            images: book.imageManifest.isEmpty ? nil : book.imageManifest,
            schema: hints
        )
        guard let data = try? encoder.encode(package) else { return }

        let panel = NSSavePanel()
        panel.title = "Export World Bible"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = book.title.isEmpty ? "World Bible" : "\(book.title) — World Bible"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Import

    private func importWorldBible() {
        let panel = NSOpenPanel()
        panel.title = "Import World Bible"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            // Try strict round-trip format first.
            if let pkg = try? JSONDecoder().decode(WorldBiblePackage.self, from: data) {
                mergeCoreLedger(pkg.coreLedger)
                mergeCharacters(pkg.characters.map { WorldCharacter(from: $0) })
                if let rels = pkg.relationships {
                    mergeRelationships(rels.map { CharacterRelationship(from: $0) })
                }
                if let positions = pkg.worldMapPositions {
                    for p in positions {
                        book.worldMapPositions[p.characterID] = CGPoint(x: p.x, y: p.y)
                    }
                }
                if let manifest = pkg.images {
                    book.imageManifest = manifest
                    ImageManager.shared.loadManifest(manifest)
                }
                return
            }
            // Fall back to flexible decoder for external / AI-generated JSON.
            let flex = try JSONDecoder().decode(FlexWorldBible.self, from: data)
            if let lf = flex.coreLedger { mergeCoreLedgerFlex(lf) }

            // Load image manifest and ask user to locate the media folder.
            if let manifest = flex.images, !manifest.isEmpty {
                book.imageManifest = manifest
                ImageManager.shared.loadManifest(manifest)
                let mediaPanel = NSOpenPanel()
                mediaPanel.title = "Locate Media Folder"
                mediaPanel.message = "This world bible references \(manifest.count) image\(manifest.count == 1 ? "" : "s"). Select the folder that contains them."
                mediaPanel.canChooseFiles = false
                mediaPanel.canChooseDirectories = true
                mediaPanel.allowsMultipleSelection = false
                if mediaPanel.runModal() == .OK, let folder = mediaPanel.url {
                    ImageManager.shared.customMediaDirectory = folder
                    ImageManager.shared.autoMatch(characters: book.worldCharacters)
                }
            }

            let charOffset = book.worldCharacters.count
            mergeCharacters((flex.characters ?? []).enumerated().map { i, fc in
                fc.toWorldCharacter(index: charOffset + i, kind: .character)
            })
            let thingOffset = book.worldCharacters.count
            mergeCharacters((flex.things ?? []).enumerated().map { i, ft in
                ft.toWorldCharacter(index: thingOffset + i, kind: .thing)
            })
            if let flexRels = flex.relationships {
                mergeRelationships(flexRels.compactMap { $0.resolve(against: book.worldCharacters) })
            }
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    // MARK: - Media folder picker

    private func pickMediaFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Media Folder"
        panel.message = "Select the folder containing your character and thing images."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let folder = panel.url {
            ImageManager.shared.customMediaDirectory = folder
            ImageManager.shared.autoMatch(characters: book.worldCharacters)
        }
    }

    // Only overwrite a Core Ledger field if the incoming value is non-empty.
    private func mergeCoreLedger(_ f: CoreLedgerFile) {
        if !f.genre.isEmpty              { book.coreLedger.genre              = f.genre }
        if !f.tone.isEmpty               { book.coreLedger.tone               = f.tone }
        if !f.spellingConvention.isEmpty { book.coreLedger.spellingConvention = f.spellingConvention }
        if !f.techOrMagicSystem.isEmpty  { book.coreLedger.techOrMagicSystem  = f.techOrMagicSystem }
        if !f.hardRules.isEmpty          { book.coreLedger.hardRules          = f.hardRules }
        if !f.styleNotes.isEmpty         { book.coreLedger.styleNotes         = f.styleNotes }
    }

    private func mergeCoreLedgerFlex(_ lf: FlexWorldBible.FlexLedger) {
        if let v = lf.genre,              !v.isEmpty { book.coreLedger.genre              = v }
        if let v = lf.tone,               !v.isEmpty { book.coreLedger.tone               = v }
        if let v = lf.spellingConvention, !v.isEmpty { book.coreLedger.spellingConvention = v }
        if let v = lf.techOrMagicSystem,  !v.isEmpty { book.coreLedger.techOrMagicSystem  = v }
        if let v = lf.hardRules,          !v.isEmpty { book.coreLedger.hardRules          = v }
        if let v = lf.styleNotes,         !v.isEmpty { book.coreLedger.styleNotes         = v }
    }

    // Upsert by name: update existing entity's non-empty fields, or append if new.
    private func mergeCharacters(_ incoming: [WorldCharacter]) {
        for c in incoming {
            if let existing = book.worldCharacters.first(where: {
                $0.name.lowercased() == c.name.lowercased()
            }) {
                if !c.biography.isEmpty            { existing.biography            = c.biography }
                if !c.physicalDescription.isEmpty  { existing.physicalDescription  = c.physicalDescription }
                if !c.psychologicalProfile.isEmpty { existing.psychologicalProfile = c.psychologicalProfile }
                if !c.personalVoice.isEmpty        { existing.personalVoice        = c.personalVoice }
                if !c.sensoryAnchors.isEmpty       { existing.sensoryAnchors       = c.sensoryAnchors }
                if !c.notes.isEmpty                { existing.notes                = c.notes }
                if !c.stats.isEmpty                { existing.stats                = c.stats }
                if c.kind != .character            { existing.kind                 = c.kind }
                if let ref = c.imageRef, !ref.isEmpty { existing.imageRef = ref }
            } else {
                c.order = book.worldCharacters.count
                book.worldCharacters.append(c)
            }
        }
    }

    // Add relationship only if this exact fromID→toID pair doesn't already exist.
    private func mergeRelationships(_ incoming: [CharacterRelationship]) {
        for rel in incoming {
            guard !book.relationships.contains(where: {
                $0.fromID == rel.fromID && $0.toID == rel.toID
            }) else { continue }
            book.relationships.append(rel)
        }
    }
}

// MARK: - Tab button

private struct WorldBibleTab: View {
    let label: String
    let icon: String
    let tab: WorldBibleView.Tab
    @Binding var current: WorldBibleView.Tab

    var body: some View {
        Button { current = tab } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .medium))
                Text(label)
            }
        }
        .buttonStyle(NavPillButtonStyle(isActive: current == tab, accent: AppTheme.accentWorld))
    }
}

// MARK: - Core Ledger form

private struct CoreLedgerForm: View {
    @Bindable var ledger: CoreLedger

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LedgerField(label: "Genre",              placeholder: "e.g. Dark Fantasy, Literary Fiction…",          text: $ledger.genre)
                LedgerField(label: "Tone",               placeholder: "e.g. Gritty & tense, Whimsical & warm…",       text: $ledger.tone)
                LedgerField(label: "Spelling Convention", placeholder: "e.g. UK English, US English…",                 text: $ledger.spellingConvention)
                LedgerField(label: "Tech / Magic System", placeholder: "How does magic or technology work?",           text: $ledger.techOrMagicSystem, multiline: true)
                LedgerField(label: "Hard Rules",          placeholder: "Inviolable rules the AI must never break…",   text: $ledger.hardRules, multiline: true)
                LedgerField(label: "Style Notes",         placeholder: "POV, tense, sentence rhythm, prose style…",   text: $ledger.styleNotes, multiline: true)
            }
            .padding(24)
        }
        .background(AppTheme.surface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LedgerField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var multiline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.accentWorld)
                .tracking(0.8)
            if multiline {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(3...8)
                    .padding(10)
                    .background(AppTheme.border.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(10)
                    .background(AppTheme.border.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Character Vault

private struct CharacterVaultView: View {
    @Bindable var book: Book
    @State private var selectedID: UUID? = nil
    @State private var listWidth: CGFloat = 210
    @State private var portraitPanelWidth: CGFloat = 320
    @State private var portraitCollapsed = false
    @State private var activeKind: WorldEntityKind = .character

    private var filteredEntities: [WorldCharacter] {
        book.worldCharacters.filter { $0.kind == activeKind }
    }

    private var selectedChar: WorldCharacter? {
        guard let id = selectedID else { return nil }
        return filteredEntities.first { $0.id == id }
    }

    private var hasPortrait: Bool { selectedChar?.hasImage == true }

    var body: some View {
        HStack(spacing: 0) {
            entityList
            PanelDivider {
                listWidth = min(340, max(160, listWidth + $0))
            } onEnd: {}
            entityDetail
            // Divider hidden when panel is collapsed or no portrait
            PanelDivider {
                portraitPanelWidth = min(600, max(160, portraitPanelWidth - $0))
            } onEnd: {}
            .opacity(hasPortrait && !portraitCollapsed ? 1 : 0)
            .allowsHitTesting(hasPortrait && !portraitCollapsed)
            // Panel always in hierarchy for stable PanelDivider identity
            ZStack {
                if let char = selectedChar, char.hasImage {
                    if portraitCollapsed {
                        collapsedStrip
                    } else {
                        portraitPanelContent(for: char)
                    }
                }
            }
            .frame(width: hasPortrait ? (portraitCollapsed ? 32 : portraitPanelWidth) : 0)
            .clipped()
            .animation(.easeInOut(duration: 0.22), value: portraitCollapsed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collapsedStrip: some View {
        VStack(spacing: 0) {
            Button { portraitCollapsed = false } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Expand portrait")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle().fill(AppTheme.border).frame(width: 1)
        }
    }

    @ViewBuilder
    private func portraitPanelContent(for char: WorldCharacter) -> some View {
        let isCircle = char.kind == .character
        VStack(alignment: .leading, spacing: 16) {
            // Header row with minimise button
            HStack {
                Text(isCircle ? "PORTRAIT" : "IMAGE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.accentWorld)
                    .tracking(0.8)
                Spacer()
                Button { portraitCollapsed = true } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                }
                .buttonStyle(GhostToolButtonStyle())
                .help("Minimise portrait")
            }

            Image(nsImage: char.resolvedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 16)))
                .overlay {
                    if isCircle { Circle().stroke(AppTheme.border, lineWidth: 1) }
                    else { RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1) }
                }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("ID")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.accentWorld)
                    .tracking(0.8)
                Text(char.id.uuidString)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
    }

    // MARK: List

    private var entityList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(WorldEntityKind.allCases, id: \.self) { k in
                    Button {
                        activeKind = k
                        selectedID = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: k.listIcon).font(.system(size: 10, weight: .medium))
                            Text(k == .character ? "People" : "Things")
                        }
                    }
                    .buttonStyle(NavPillButtonStyle(isActive: activeKind == k, accent: AppTheme.accentWorld))
                }
                Spacer()
                Button { addEntry() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accentWorld)
                        .padding(5)
                }
                .buttonStyle(.plain)
                .help(activeKind == .character ? "Add character" : "Add place or thing")
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(AppTheme.background)

            Divider().background(AppTheme.border)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(filteredEntities) { entity in
                        CharacterRow(character: entity, isSelected: selectedID == entity.id) {
                            selectedID = entity.id
                        }
                    }
                }
                .padding(8)
            }
            .background(AppTheme.sidebar)

            if !filteredEntities.isEmpty {
                Divider().background(AppTheme.border)
                Button { deleteSelected() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .disabled(selectedID == nil)
                .opacity(selectedID == nil ? 0.3 : 1)
                .help("Delete selected entry")
                .frame(maxWidth: .infinity)
                .background(AppTheme.background)
            }
        }
        .frame(width: listWidth)
    }

    // MARK: Detail

    @ViewBuilder
    private var entityDetail: some View {
        if let char = selectedChar {
            CharacterDetailView(character: char)
        } else {
            VStack(spacing: 10) {
                Image(systemName: activeKind == .character ? "person.crop.circle.badge.plus" : "mappin.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accentWorld.opacity(0.3))
                Text(filteredEntities.isEmpty
                     ? (activeKind == .character ? "Add a character to begin" : "Add a thing to begin")
                     : (activeKind == .character ? "Select a character" : "Select a thing"))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.surface)
        }
    }

    private func addEntry() {
        if activeKind == .character { book.addWorldCharacter() } else { book.addWorldThing() }
        selectedID = book.worldCharacters.last?.id
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        book.worldCharacters.removeAll { $0.id == id }
        selectedID = filteredEntities.last?.id
    }
}

private struct CharacterRow: View {
    let character: WorldCharacter
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var showThumbnailPreview = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                thumbnail
                Text(character.name.isEmpty ? "Unnamed" : character.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected ? AppTheme.sidebarSelected : (isHovered ? AppTheme.sidebarHover : Color.clear),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                character.kind = character.kind == .character ? .thing : .character
            } label: {
                Label(
                    character.kind == .character ? "Move to Things" : "Move to People",
                    systemImage: character.kind == .character ? "mappin.circle" : "person.circle"
                )
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if character.hasImage {
            Image(nsImage: character.resolvedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(character.kind == .character
                           ? AnyShape(Circle())
                           : AnyShape(RoundedRectangle(cornerRadius: 5)))
                .onHover { showThumbnailPreview = $0 }
                .popover(isPresented: $showThumbnailPreview, arrowEdge: .trailing) {
                    ImagePreviewPopover(image: character.resolvedImage, id: character.id.uuidString)
                }
        } else {
            Image(systemName: character.kind.listIcon)
                .font(.system(size: 15))
                .foregroundStyle(isSelected ? AppTheme.accentWorld : AppTheme.textSecondary)
                .frame(width: 24, height: 24)
        }
    }
}

private struct CharacterDetailView: View {
    @Bindable var character: WorldCharacter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Kind selector
                HStack(spacing: 4) {
                    Text("TYPE").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary).tracking(0.8)
                    Spacer()
                    ForEach(WorldEntityKind.allCases, id: \.self) { k in
                        Button { character.kind = k } label: {
                            HStack(spacing: 4) {
                                Image(systemName: k.listIcon).font(.system(size: 10, weight: .medium))
                                Text(k == .character ? "Person" : "Thing")
                            }
                        }
                        .buttonStyle(NavPillButtonStyle(isActive: character.kind == k, accent: AppTheme.accentWorld))
                    }
                }

                // Portrait / image controls
                portraitSection

                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("NAME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.accentWorld)
                        .tracking(0.8)
                    TextField(character.kind == .character ? "Character name…" : "Name…",
                              text: $character.name)
                        .textFieldStyle(.plain)
                        .font(AppTheme.editorialFont(18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Divider().background(AppTheme.border)

                if character.kind == .character {
                    CharDetailField(label: "Biography",
                                    placeholder: "Narrative backstory — who they are, where they came from, what shaped them…",
                                    text: $character.biography)
                    CharDetailField(label: "Physical Description",
                                    placeholder: "Height, build, hair, eyes, distinguishing features…",
                                    text: $character.physicalDescription)
                    CharDetailField(label: "Psychology",
                                    placeholder: "Core traits, fears, desires, internal conflicts…",
                                    text: $character.psychologicalProfile)
                    CharDetailField(label: "Voice & Speech",
                                    placeholder: "How they talk, verbal tics, vocabulary, accent…",
                                    text: $character.personalVoice)
                    CharDetailField(label: "Sensory Anchors",
                                    placeholder: "Smell, sound, touch, habit — the details that make them real on the page…",
                                    text: $character.sensoryAnchors)
                    CharDetailField(label: "Notes",
                                    placeholder: "Backstory, relationships, arc, secrets…",
                                    text: $character.notes)
                } else {
                    CharDetailField(label: "Biography",
                                    placeholder: "Origin, history, what makes this significant…",
                                    text: $character.biography)
                    CharDetailField(label: "Description",
                                    placeholder: "Appearance, atmosphere, key sensory details…",
                                    text: $character.physicalDescription)
                    CharDetailField(label: "Notes",
                                    placeholder: "Connections to the story, current status…",
                                    text: $character.notes)
                }

                // Stats
                statsSection
            }
            .padding(24)
        }
        .background(AppTheme.surface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STATS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.accentWorld)
                .tracking(0.8)

            if character.stats.isEmpty {
                Text("No stats yet — add one below.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                    .italic()
            } else {
                ForEach($character.stats) { $stat in
                    HStack(spacing: 8) {
                        TextField("Label", text: $stat.key)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(minWidth: 80, maxWidth: 120)
                        Text(":")
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                        TextField("Value", text: $stat.value)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Button { character.stats.removeAll { $0.id == stat.id } } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.border.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Button {
                character.stats.append(CharacterStat())
            } label: {
                Label("Add stat", systemImage: "plus.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.accentWorld)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Portrait section

    @ViewBuilder
    private var portraitSection: some View {
        let isCircle = character.kind == .character
        let size: CGFloat = 80
        VStack(alignment: .leading, spacing: 8) {
            Text(isCircle ? "PORTRAIT" : "IMAGE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.accentWorld)
                .tracking(0.8)
            HStack(spacing: 14) {
                Button { pickPortrait() } label: {
                    ZStack(alignment: .bottomTrailing) {
                        if character.hasImage {
                            Image(nsImage: character.resolvedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: size, height: size)
                                .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 12)))
                                .overlay {
                                    if isCircle { Circle().stroke(AppTheme.border, lineWidth: 1) }
                                    else { RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1) }
                                }
                        } else {
                            Group {
                                if isCircle { Circle().fill(AppTheme.border.opacity(0.20)) }
                                else { RoundedRectangle(cornerRadius: 12).fill(AppTheme.border.opacity(0.20)) }
                            }
                            .frame(width: size, height: size)
                            .overlay {
                                VStack(spacing: 5) {
                                    Image(systemName: isCircle ? "person.crop.circle.badge.plus" : "photo.badge.plus")
                                        .font(.system(size: 22))
                                    Text("Add image")
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
                            }
                        }
                        if character.hasImage {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(AppTheme.accentWorld)
                                .background(.white, in: Circle())
                                .offset(x: 4, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Click to choose an image")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Click the image to change")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    if character.portraitData != nil {
                        Button("Remove image") { character.portraitData = nil }
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                            .buttonStyle(.plain)
                    }
                    if let ref = character.imageRef, !ref.isEmpty {
                        Text("Ref: \(ref)")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func pickPortrait() {
        let panel = NSOpenPanel()
        panel.title = "Choose Image"
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .gif]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let src = NSImage(contentsOf: url) else { return }
        let maxSide: CGFloat = 400
        let s = src.size
        let scale = (s.width > maxSide || s.height > maxSide)
            ? min(maxSide / s.width, maxSide / s.height) : 1.0
        let dest = NSSize(width: round(s.width * scale), height: round(s.height * scale))
        let resized = NSImage(size: dest, flipped: false) { _ in
            src.draw(in: NSRect(origin: .zero, size: dest)); return true
        }
        character.portraitData = resized.pngData()
    }
}

private struct CharDetailField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.accentWorld)
                .tracking(0.8)
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(3...10)
                .padding(10)
                .background(AppTheme.border.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Relationship Arc Map

private struct RelationshipMapView: View {
    @Environment(Book.self) private var book
    @State private var connectMode   = false
    @State private var firstNodeID:  UUID? = nil
    @State private var pendingEdge:  PendingEdge? = nil
    @State private var chapterFilter = 0   // 0 = all
    @State private var relPanelWidth: CGFloat = 210

    private var arcChars: [WorldCharacter] {
        book.worldCharacters.filter { $0.kind == .character }
    }

    private struct PendingEdge: Identifiable {
        let id = UUID()
        let fromID: UUID
        let toID:   UUID
    }

    var body: some View {
        @Bindable var book = book
        VStack(spacing: 0) {
            toolbar
            Divider().background(AppTheme.border)
            HStack(spacing: 0) {
                canvas
                PanelDivider {
                    relPanelWidth = min(400, max(160, relPanelWidth - $0))
                } onEnd: {}
                relationshipsPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $pendingEdge) { edge in
            AddRelationshipSheet(
                fromID: edge.fromID,
                toID:   edge.toID,
                chapters: book.chapters
            ) { rel in
                book.relationships.append(rel)
            }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                connectMode.toggle()
                if !connectMode { firstNodeID = nil }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: connectMode ? "xmark.circle" : "line.3.crossed.swirl.circle")
                        .font(.system(size: 11, weight: .medium))
                    Text(connectMode
                         ? (firstNodeID == nil ? "Pick first…" : "Pick second…")
                         : "Connect")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(connectMode ? .white : AppTheme.accentWorld)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(connectMode ? AppTheme.accentWorld : AppTheme.accentWorld.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Click two character nodes to draw a relationship arc")

            Button {
                book.worldMapPositions.removeAll()
            } label: {
                Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(6)
                    .background(AppTheme.border.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Reset node layout to circle")

            if !book.chapters.isEmpty {
                Divider().frame(height: 16)
                HStack(spacing: 6) {
                    Image(systemName: "book.pages").font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Show up to ch.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                    Stepper(value: $chapterFilter, in: 0...book.chapters.count) {
                        Text(chapterFilter == 0 ? "All" : "\(chapterFilter)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 26, alignment: .leading)
                    }
                }
            }

            Spacer()

            // Legend
            HStack(spacing: 10) {
                ForEach(RelationshipType.allCases, id: \.self) { t in
                    HStack(spacing: 4) {
                        Capsule().fill(t.color).frame(width: 18, height: 3)
                        Text(t.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(AppTheme.background)
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let positions = effectivePositions(in: geo.size)
            let visRels   = visibleRelationships()

            ZStack {
                AppTheme.background.ignoresSafeArea()

                if arcChars.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.25))
                        Text("Add characters in the Characters section to begin the arc map")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 280)
                } else {
                    // Edge arcs
                    Canvas { ctx, _ in
                        drawEdges(ctx: ctx, positions: positions, rels: visRels)
                    }
                    .allowsHitTesting(false)

                    // Character nodes
                    ForEach(arcChars) { char in
                        ArcNode(
                            char: char,
                            isHighlighted: firstNodeID == char.id,
                            connectMode: connectMode
                        )
                        .position(positions[char.id] ?? CGPoint(x: geo.size.width/2, y: geo.size.height/2))
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .named("arcMap"))
                                .onChanged { drag in
                                    guard !connectMode else { return }
                                    book.worldMapPositions[char.id] = clamped(drag.location, in: geo.size)
                                }
                        )
                        .onTapGesture { handleTap(char.id) }
                    }
                }
            }
            .coordinateSpace(name: "arcMap")
        }
    }

    // MARK: Relationships panel

    private var relationshipsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ARCS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.0)
                Spacer()
                Text("\(book.relationships.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(AppTheme.background)

            Divider().background(AppTheme.border)

            if book.relationships.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.2))
                    Text("No arcs yet.\nUse Connect to link characters.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.sidebar)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(book.relationships) { rel in
                            RelationshipRow(
                                rel: rel,
                                fromName: book.worldCharacters.first { $0.id == rel.fromID }?.name ?? "?",
                                toName:   book.worldCharacters.first { $0.id == rel.toID   }?.name ?? "?"
                            ) {
                                book.relationships.removeAll { $0.id == rel.id }
                            }
                        }
                    }
                    .padding(6)
                }
                .background(AppTheme.sidebar)
            }
        }
        .frame(width: relPanelWidth)
    }

    // MARK: Drawing

    private func drawEdges(ctx: GraphicsContext, positions: [UUID: CGPoint], rels: [CharacterRelationship]) {
        let nodeR: CGFloat = 26
        for rel in rels {
            guard let from = positions[rel.fromID], let to = positions[rel.toID] else { continue }
            let dx = to.x - from.x
            let dy = to.y - from.y
            let len = max(1, sqrt(dx*dx + dy*dy))
            let fromEdge = CGPoint(x: from.x + dx/len * nodeR, y: from.y + dy/len * nodeR)
            let toEdge   = CGPoint(x: to.x   - dx/len * nodeR, y: to.y   - dy/len * nodeR)

            // Quadratic bezier — control point offset perpendicular to midpoint
            let mid  = CGPoint(x: (fromEdge.x + toEdge.x)/2, y: (fromEdge.y + toEdge.y)/2)
            let perp = CGPoint(x: -dy/len * len * 0.12, y: dx/len * len * 0.12)
            let ctrl = CGPoint(x: mid.x + perp.x, y: mid.y + perp.y)

            var path = Path()
            path.move(to: fromEdge)
            path.addQuadCurve(to: toEdge, control: ctrl)

            ctx.stroke(path, with: .color(rel.type.color.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // Small arrowhead at toEdge
            let arrowLen: CGFloat = 8
            let angle = atan2(toEdge.y - ctrl.y, toEdge.x - ctrl.x)
            var arrow = Path()
            arrow.move(to: toEdge)
            arrow.addLine(to: CGPoint(x: toEdge.x - arrowLen * cos(angle - 0.4),
                                      y: toEdge.y - arrowLen * sin(angle - 0.4)))
            arrow.move(to: toEdge)
            arrow.addLine(to: CGPoint(x: toEdge.x - arrowLen * cos(angle + 0.4),
                                      y: toEdge.y - arrowLen * sin(angle + 0.4)))
            ctx.stroke(arrow, with: .color(rel.type.color.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))

            // Label at bezier midpoint
            if !rel.label.isEmpty {
                let labelPt = CGPoint(
                    x: 0.25*fromEdge.x + 0.5*ctrl.x + 0.25*toEdge.x,
                    y: 0.25*fromEdge.y + 0.5*ctrl.y + 0.25*toEdge.y - 10
                )
                ctx.draw(
                    Text(rel.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(rel.type.color),
                    at: labelPt
                )
            }
        }
    }

    // MARK: Helpers

    private func effectivePositions(in size: CGSize) -> [UUID: CGPoint] {
        let chars = arcChars
        let count = max(1, chars.count)
        var result: [UUID: CGPoint] = [:]
        for (idx, char) in chars.enumerated() {
            if let stored = book.worldMapPositions[char.id] {
                result[char.id] = stored
            } else {
                let angle  = (2 * .pi * Double(idx)) / Double(count) - .pi / 2
                let radius = min(size.width - 100, size.height - 100) * 0.42
                result[char.id] = CGPoint(
                    x: size.width  / 2 + radius * cos(angle),
                    y: size.height / 2 + radius * sin(angle)
                )
            }
        }
        return result
    }

    private func visibleRelationships() -> [CharacterRelationship] {
        guard chapterFilter > 0 else { return book.relationships }
        return book.relationships.filter { ($0.chapterIntroduced ?? 0) <= chapterFilter }
    }

    private func handleTap(_ id: UUID) {
        guard connectMode else { return }
        if firstNodeID == nil {
            firstNodeID = id
        } else if firstNodeID != id {
            pendingEdge  = PendingEdge(fromID: firstNodeID!, toID: id)
            firstNodeID  = nil
            connectMode  = false
        }
    }

    private func clamped(_ pt: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: max(48, min(size.width  - 48, pt.x)),
                y: max(48, min(size.height - 48, pt.y)))
    }
}

// MARK: - Arc node

private struct ArcNode: View {
    let char: WorldCharacter
    let isHighlighted: Bool
    let connectMode: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(isHighlighted ? AppTheme.accentWorld : AppTheme.surface)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(isHighlighted ? 0.22 : 0.10), radius: 6, y: 2)
                Circle()
                    .stroke(isHighlighted ? AppTheme.accentWorld : AppTheme.border,
                            lineWidth: isHighlighted ? 2.5 : 1.5)
                    .frame(width: 52, height: 52)
                if char.hasImage {
                    Image(nsImage: char.resolvedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text(initials(char.name))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(isHighlighted ? .white : AppTheme.textPrimary)
                }
            }
            .scaleEffect(connectMode ? 1.06 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: connectMode)

            Text(char.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 84)
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Relationship row

private struct RelationshipRow: View {
    let rel: CharacterRelationship
    let fromName: String
    let toName:   String
    let onDelete: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(rel.type.color).frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(fromName).fontWeight(.medium)
                    Image(systemName: "arrow.right").font(.system(size: 8))
                        .foregroundStyle(rel.type.color)
                    Text(toName).fontWeight(.medium)
                }
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

                HStack(spacing: 4) {
                    Text(rel.type.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(rel.type.color)
                    if !rel.label.isEmpty {
                        Text("· \(rel.label)")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    if let ch = rel.chapterIntroduced {
                        Text("ch.\(ch)")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    }
                }
            }
            Spacer()
            if hovered {
                Button { onDelete() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(5)
                }
                .buttonStyle(.plain)
                .help("Remove arc")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(hovered ? AppTheme.sidebarHover : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
}

// MARK: - Add relationship sheet

private struct AddRelationshipSheet: View {
    @Environment(Book.self) private var book
    @Environment(\.dismiss) private var dismiss

    let fromID:   UUID
    let toID:     UUID
    let chapters: [Chapter]
    let onAdd:    (CharacterRelationship) -> Void

    @State private var label        = ""
    @State private var type: RelationshipType = .neutral
    @State private var pinChapter   = false
    @State private var chapterIndex = 1

    private var fromName: String { book.worldCharacters.first { $0.id == fromID }?.name ?? "?" }
    private var toName:   String { book.worldCharacters.first { $0.id == toID   }?.name ?? "?" }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Relationship Arc")
                .font(AppTheme.editorialFont(17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            // Characters
            HStack(spacing: 0) {
                Spacer()
                characterBadge(fromName)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(type.color)
                    .padding(.horizontal, 10)
                characterBadge(toName)
                Spacer()
            }

            // Label
            VStack(alignment: .leading, spacing: 6) {
                Text("LABEL").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.accentWorld).tracking(0.8)
                TextField("e.g. old friends, uneasy alliance…", text: $label)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(9)
                    .background(AppTheme.border.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }

            // Type grid
            VStack(alignment: .leading, spacing: 8) {
                Text("TYPE").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.accentWorld).tracking(0.8)
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(RelationshipType.allCases, id: \.self) { t in
                        Button { type = t } label: {
                            Text(t.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(type == t ? .white : t.color)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(type == t ? t.color : t.color.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Chapter introduced
            if !chapters.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Pin to a chapter", isOn: $pinChapter)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    if pinChapter {
                        Picker("Chapter", selection: $chapterIndex) {
                            ForEach(Array(chapters.enumerated()), id: \.offset) { i, ch in
                                Text("Ch. \(i+1): \(ch.title)").tag(i+1)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }

            Divider().background(AppTheme.border)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Add Arc") {
                    onAdd(CharacterRelationship(
                        fromID: fromID, toID: toID,
                        label: label, type: type,
                        chapterIntroduced: pinChapter ? chapterIndex : nil
                    ))
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(type.color, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(AppTheme.surface)
    }

    @ViewBuilder
    private func characterBadge(_ name: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(AppTheme.accentWorld.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(name.prefix(2)).uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accentWorld)
                )
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
