import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export package (strict, round-trips cleanly)

private struct WorldBiblePackage: Codable {
    var coreLedger: CoreLedgerFile
    var characters: [WorldCharacterFile]
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

    struct FlexCharacter: Decodable {
        // Bookworm native keys — id decoded as String so invalid UUIDs don't throw
        let idString:             String?
        let order:                Int?
        let physicalDescription:  String?
        let psychologicalProfile: String?
        let personalVoice:        String?
        let notes:                String?
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
            case sensory_anchors = "sensory_anchors"
        }

        func toWorldCharacter(index: Int) -> WorldCharacter {
            let uuid = idString.flatMap { UUID(uuidString: $0) } ?? UUID()
            let c = WorldCharacter(id: uuid, name: name ?? "Unnamed", order: order ?? index)
            c.physicalDescription  = physicalDescription ?? sensory_anchors ?? description ?? ""
            c.psychologicalProfile = psychologicalProfile ?? traits ?? ""
            c.personalVoice        = personalVoice ?? voice ?? ""
            // Combine leftover fields that don't have a direct mapping into notes
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
}

// MARK: - View

struct WorldBibleView: View {
    @Environment(Book.self) private var book
    @State private var tab: Tab = .coreLedger
    @State private var importError: String? = nil
    @State private var showImportError = false

    enum Tab { case coreLedger, characters }

    var body: some View {
        @Bindable var book = book
        VStack(spacing: 0) {
            PanelHeader(
                step: "W",
                label: "WORLD BIBLE",
                subtitle: "genre, rules, and characters",
                accent: AppTheme.accentWorld
            ) {
                HStack(spacing: 4) {
                    WorldBibleTab(label: "Core Ledger", icon: "doc.text.fill", tab: .coreLedger, current: $tab)
                    WorldBibleTab(label: "Characters",  icon: "person.2.fill", tab: .characters,  current: $tab)

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
                    .help("Import world bible from a .worldbible JSON file")

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
        let package = WorldBiblePackage(
            coreLedger: book.coreLedger.toFile(),
            characters: book.worldCharacters.map { $0.toFile() }
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
            // Try our own strict round-trip format first.
            if let pkg = try? JSONDecoder().decode(WorldBiblePackage.self, from: data) {
                book.coreLedger.apply(pkg.coreLedger)
                book.worldCharacters = pkg.characters.map { WorldCharacter(from: $0) }
                return
            }
            // Fall back to flexible decoder that handles external / AI-generated JSON.
            let flex = try JSONDecoder().decode(FlexWorldBible.self, from: data)
            if let lf = flex.coreLedger {
                book.coreLedger.apply(lf.toCoreFile())
            }
            book.worldCharacters = (flex.characters ?? [])
                .enumerated()
                .map { i, fc in fc.toWorldCharacter(index: i) }
        } catch {
            importError = error.localizedDescription
            showImportError = true
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
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(current == tab ? AppTheme.accentWorld : AppTheme.textSecondary)
            .background(
                current == tab ? AppTheme.accentWorld.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
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
    @State private var listWidth: CGFloat = 200

    private var selectedChar: WorldCharacter? {
        guard let id = selectedID else { return nil }
        return book.worldCharacters.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            characterList
            PanelDivider {
                listWidth = min(340, max(140, listWidth + $0))
            } onEnd: {}
            characterDetail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: List

    private var characterList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CHARACTERS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.0)
                Spacer()
                Button { addCharacter() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accentWorld)
                        .padding(5)
                }
                .buttonStyle(.plain)
                .help("Add character")
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(AppTheme.background)

            Divider().background(AppTheme.border)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(book.worldCharacters) { char in
                        CharacterRow(character: char, isSelected: selectedID == char.id) {
                            selectedID = char.id
                        }
                    }
                }
                .padding(8)
            }
            .background(AppTheme.sidebar)

            if !book.worldCharacters.isEmpty {
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
                .help("Delete selected character")
                .frame(maxWidth: .infinity)
                .background(AppTheme.background)
            }
        }
        .frame(width: listWidth)
    }

    // MARK: Detail

    @ViewBuilder
    private var characterDetail: some View {
        if let char = selectedChar {
            CharacterDetailView(character: char)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accentWorld.opacity(0.3))
                Text(book.worldCharacters.isEmpty ? "Add a character to begin" : "Select a character")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.surface)
        }
    }

    private func addCharacter() {
        book.addWorldCharacter()
        selectedID = book.worldCharacters.last?.id
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        book.worldCharacters.removeAll { $0.id == id }
        selectedID = book.worldCharacters.last?.id
    }
}

private struct CharacterRow: View {
    let character: WorldCharacter
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? AppTheme.accentWorld : AppTheme.textSecondary)
                    .frame(width: 20)
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
    }
}

private struct CharacterDetailView: View {
    @Bindable var character: WorldCharacter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NAME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.accentWorld)
                        .tracking(0.8)
                    TextField("Character name…", text: $character.name)
                        .textFieldStyle(.plain)
                        .font(AppTheme.editorialFont(18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Divider().background(AppTheme.border)

                CharDetailField(label: "Physical Description",
                                placeholder: "Height, build, hair, eyes, distinguishing features…",
                                text: $character.physicalDescription)
                CharDetailField(label: "Psychology",
                                placeholder: "Core traits, fears, desires, internal conflicts…",
                                text: $character.psychologicalProfile)
                CharDetailField(label: "Voice & Speech",
                                placeholder: "How they talk, verbal tics, vocabulary, accent…",
                                text: $character.personalVoice)
                CharDetailField(label: "Notes",
                                placeholder: "Backstory, relationships, arc, secrets…",
                                text: $character.notes)
            }
            .padding(24)
        }
        .background(AppTheme.surface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
