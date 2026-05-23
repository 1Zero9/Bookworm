import SwiftUI
import UniformTypeIdentifiers

struct CorkboardView: View {
    @Environment(Book.self) private var book
    @EnvironmentObject private var layout: LayoutStore
    
    @State private var columnsCount: Int = 3
    @State private var draggedItem: Chapter?
    @State private var generatingChapterIDs: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            PanelHeader(
                step: "5",
                label: "STORYBOARD",
                subtitle: "Tactile Scene Corkboard Outline",
                accent: AppTheme.accentWrite
            ) {
                HStack(spacing: 16) {
                    // Columns count slider
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.split.3x3")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                        TactileSlider(
                            value: Binding(
                                get: { Double(columnsCount) },
                                set: { columnsCount = Int($0) }
                            ),
                            range: 1.0...4.0,
                            accentColor: AppTheme.accentWrite
                        )
                        .frame(width: 80)
                        
                        Text("\(columnsCount) Cols")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 40, alignment: .leading)
                    }
                    .padding(.trailing, 8)
                    
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            book.addChapter()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add Chapter")
                        }
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                }
            }
            
            Divider().background(AppTheme.border)
            
            // Canvas/Grid area
            ZStack {
                // Dot matrix corkboard background
                DotMatrixBackground()
                
                if book.chapters.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                        Text("No Chapters Yet")
                            .font(AppTheme.editorialFont(16, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Create a chapter to start organizing your story board.")
                            .font(AppTheme.uiFont(11))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                book.addChapter()
                            }
                        } label: {
                            Text("Create Chapter")
                        }
                        .buttonStyle(PrimaryPillButtonStyle())
                        .frame(width: 140)
                        .padding(.top, 8)
                    }
                } else {
                    ScrollView {
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: columnsCount)
                        
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(book.chapters.sorted(by: { $0.order < $1.order })) { chapter in
                                IndexCardView(
                                    chapter: chapter,
                                    book: book,
                                    draggedItem: $draggedItem,
                                    generatingChapterIDs: $generatingChapterIDs,
                                    onGenerateSynopsis: {
                                        triggerAISynopsis(for: chapter)
                                    }
                                )
                                .onDrag {
                                    self.draggedItem = chapter
                                    return NSItemProvider(object: chapter.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [.text],
                                    delegate: CorkboardDropDelegate(
                                        item: chapter,
                                        book: book,
                                        draggedItem: $draggedItem
                                    )
                                )
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.background)
    }
    
    // MARK: - AI Action
    
    private func triggerAISynopsis(for chapter: Chapter) {
        generatingChapterIDs.insert(chapter.id)
        
        Task {
            do {
                let summary = try await GeminiClient.shared.summarizeChapter(
                    text: chapter.rawText,
                    title: chapter.title
                )
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        chapter.synopsis = summary
                        generatingChapterIDs.remove(chapter.id)
                    }
                }
            } catch {
                await MainActor.run {
                    generatingChapterIDs.remove(chapter.id)
                    // Let the user know if synthesis failed (e.g. no API key set)
                    let alert = NSAlert()
                    alert.messageText = "AI Synopsis Generation Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
}

// MARK: - Dot Matrix Background

struct DotMatrixBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 1.5
            let spacing: CGFloat = 20
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(AppTheme.textSecondary.opacity(colorScheme == .dark ? 0.15 : 0.10))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - IndexCardView

struct IndexCardView: View {
    @Bindable var chapter: Chapter
    let book: Book
    @Binding var draggedItem: Chapter?
    @Binding var generatingChapterIDs: Set<UUID>
    let onGenerateSynopsis: () -> Void
    
    @State private var hovered = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isGenerating: Bool {
        generatingChapterIDs.contains(chapter.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Card Header
            HStack(spacing: 8) {
                // Number / Icon indicator
                Text("\(AppTheme.emoji(for: chapter.order)) \(String(format: "%02d", chapter.order + 1))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Spacer()
                
                // Status Pill
                Menu {
                    ForEach(ChapterStatus.allCases, id: \.self) { status in
                        Button {
                            chapter.status = status
                        } label: {
                            HStack {
                                Image(systemName: status.icon)
                                Text(status.rawValue)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: onGenerateSynopsis) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("AI Auto-Synopsis")
                        }
                    }
                    .disabled(isGenerating)
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            book.deleteChapter(chapter)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Chapter")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(chapter.status.color)
                            .frame(width: 6, height: 6)
                        Text(chapter.status.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(chapter.status.color.opacity(0.12), in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            
            // Editable Scene Title
            TextField("Untitled Chapter", text: $chapter.title)
                .font(AppTheme.editorialFont(14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 10)
            
            Divider()
                .background(AppTheme.border)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            
            // Synopsis editor
            ZStack(alignment: .topLeading) {
                if chapter.synopsis.isEmpty && !isGenerating {
                    Text("Write a brief scene synopsis here, or tap the magic wand to generate one using AI...")
                        .font(AppTheme.uiFont(11))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                        .allowsHitTesting(false)
                }
                
                HStack(alignment: .top, spacing: 6) {
                    if isGenerating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Synthesizing prose synopsis...")
                                .font(AppTheme.uiFont(11))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    } else {
                        TextField("", text: $chapter.synopsis, axis: .vertical)
                            .font(AppTheme.uiFont(11))
                            .foregroundStyle(AppTheme.textSecondary)
                            .textFieldStyle(.plain)
                            .lineLimit(4...8)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Tiny Magic Wand trigger
                    if !isGenerating {
                        Button(action: onGenerateSynopsis) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.accentWrite)
                                .opacity(hovered ? 0.8 : 0.4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 10)
                        .help("Auto-distill a 1-sentence outline using Gemini AI")
                    }
                }
            }
            .frame(minHeight: 80, alignment: .topLeading)
            
            Spacer(minLength: 0)
            
            // Subplot pins & Character avatars bottom border
            let beats = book.plotBeats.filter { $0.chapterID == chapter.id }
            let characterIDs = Array(Set(beats.flatMap { $0.characterIDs }))
            let activeCharacters = book.worldCharacters.filter { characterIDs.contains($0.id) }
            
            if !beats.isEmpty || !activeCharacters.isEmpty {
                Divider().background(AppTheme.border)
                
                HStack(spacing: 8) {
                    // Subplot pins
                    if !beats.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(beats) { beat in
                                if let subplot = book.subplots.first(where: { $0.id == beat.subplotID }) {
                                    Circle()
                                        .fill(Color(hex: subplot.colorHex))
                                        .frame(width: 8, height: 8)
                                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                                        .help("\(subplot.name): \(beat.title)")
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Character avatars
                    if !activeCharacters.isEmpty {
                        HStack(spacing: -4) {
                            ForEach(activeCharacters) { character in
                                Text(String(character.name.prefix(1)).uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(avatarColor(for: character.name), in: Circle())
                                    .overlay(Circle().stroke(AppTheme.surface, lineWidth: 1))
                                    .help(character.name)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.sidebar.opacity(0.3))
            }
        }
        .frame(minHeight: 180)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(hovered ? AppTheme.accentWrite.opacity(0.6) : AppTheme.border, lineWidth: hovered ? 1.5 : 1.0)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? (hovered ? 0.35 : 0.16) : (hovered ? 0.12 : 0.04)),
            radius: hovered ? 14 : 8,
            x: 0,
            y: hovered ? 6 : 3
        )
        .scaleEffect(hovered ? 1.025 : 1.0)
        .onHover { hovered = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hovered)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: chapter.order)
    }
    
    // Consistent colors for active character avatars based on their name
    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(hex: "#7C8CFF"), // Indigo
            Color(hex: "#3DBFB8"), // Teal
            Color(hex: "#C9963A"), // Gold
            Color(hex: "#F4B183"), // Peach
            Color(hex: "#9B72D0"), // Plum
            Color(hex: "#458C5A"), // Sage
            Color(hex: "#C84C5E"), // Rose
            Color(hex: "#2A82B8")  // Breeze
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Drop Delegate for Spring Grid Reordering

struct CorkboardDropDelegate: DropDelegate {
    let item: Chapter
    let book: Book
    @Binding var draggedItem: Chapter?
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        if draggedItem.id != item.id {
            guard let fromIndex = book.chapters.firstIndex(where: { $0.id == draggedItem.id }),
                  let toIndex = book.chapters.firstIndex(where: { $0.id == item.id }) else { return }
            
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                book.moveChapters(from: IndexSet(integer: fromIndex), to: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
