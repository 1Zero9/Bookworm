import SwiftUI

struct SidebarView: View {
    @Environment(Book.self) private var book
    @State private var renamingID: UUID? = nil
    @State private var renameText: String = ""
    @State private var showLibrary = false
    @State private var showSettings = false
    @State private var hoveredVersion = false

    var body: some View {
        @Bindable var book = book

        VStack(spacing: 0) {
            // Book identity header
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    if let icon = AppTheme.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                            .mask(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        IconToolButton(icon: "clock.arrow.circlepath", tip: "Library — recent books") { showLibrary = true }
                        IconToolButton(icon: "folder", tip: "Open… (⌘O)") { book.open() }
                        SaveButton(book: book)
                    }
                }

                TextField("Novel Title", text: $book.title)
                    .font(AppTheme.editorialFont(16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .textFieldStyle(.plain)

                TextField("Your Name", text: $book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textFieldStyle(.plain)

                if let url = book.fileURL {
                    Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                        .lineLimit(1)
                }
                let totalWords = book.chapters.reduce(0) {
                    $0 + $1.rawText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                }
                Text(totalWords >= 1000
                     ? String(format: "%.1fk words", Double(totalWords) / 1000.0)
                     : "\(totalWords) words")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(AppTheme.border)

            // Organise header
            HStack(spacing: 8) {
                FeatureDot(color: AppTheme.accentWrite)
                Text("ORGANISE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ScrollViewReader { sidebarProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        SidebarItem(
                            symbol: "paintpalette",
                            label: "Cover",
                            isSelected: book.selectedChapterID == nil && book.visibleChapterID == nil,
                            isRenaming: false,
                            renameText: .constant("")
                        ) {
                            book.selectedChapterID = nil
                            book.visibleChapterID = nil
                        } onCommitRename: {}

                        if !book.chapters.isEmpty {
                            Text("CHAPTERS")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                                .tracking(1.0)
                                .padding(.horizontal, 10)
                                .padding(.top, 10)
                                .padding(.bottom, 2)
                        }

                        ForEach(Array(book.chapters.enumerated()), id: \.element.id) { idx, chapter in
                            @Bindable var chapter = chapter
                            let isRen = renamingID == chapter.id
                            // Scroll-driven visible chapter takes priority for the highlight pill.
                            let activeID = book.visibleChapterID ?? book.selectedChapterID
                            SidebarItem(
                                symbol: nil,
                                emoji: AppTheme.emoji(for: idx),
                                label: chapter.title,
                                isSelected: activeID == chapter.id,
                                isRenaming: isRen,
                                renameText: isRen
                                    ? Binding(get: { renameText }, set: { renameText = $0 })
                                    : .constant(chapter.title),
                                chapterStatus: chapter.status,
                                isChapter: true,
                                wordCount: chapter.rawText
                                    .components(separatedBy: .whitespacesAndNewlines)
                                    .filter { !$0.isEmpty }.count
                            ) {
                                if renamingID == nil {
                                    book.selectedChapterID = chapter.id
                                    book.visibleChapterID = nil  // clear scroll highlight on explicit click
                                }
                            } onCommitRename: {
                                if !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                                    chapter.title = renameText
                                }
                                renamingID = nil
                            }
                            .id(chapter.id)
                            .contextMenu {
                                Button("Rename") {
                                    book.selectedChapterID = chapter.id
                                    renameText = chapter.title
                                    renamingID = chapter.id
                                }
                                Divider()
                                Menu("Status") {
                                    ForEach(ChapterStatus.allCases, id: \.self) { s in
                                        Button {
                                            chapter.status = s
                                        } label: {
                                            Label(s.rawValue, systemImage: chapter.status == s ? "checkmark" : s.icon)
                                        }
                                    }
                                }
                                Divider()
                                Button("Delete", role: .destructive) { book.deleteChapter(chapter) }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                // Auto-scroll sidebar to keep the highlighted chapter pill visible.
                .onChange(of: book.visibleChapterID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        sidebarProxy.scrollTo(id, anchor: .center)
                    }
                }
            }

            Divider().background(AppTheme.border)

            // New Chapter button
            Button { book.addChapter() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    Text("New Chapter")
                }
                .help("Add a new chapter")
            }
            .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentWrite))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)

            HStack {
                Button { showSettings = true } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .help("Settings")
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Bookworm \(AppTheme.version) (Build \(AppTheme.build))")
                    .font(.system(size: 9, weight: hoveredVersion ? .bold : .medium))
                    .foregroundStyle(hoveredVersion ? AppTheme.accentWrite : AppTheme.textSecondary.opacity(0.65))
                    .scaleEffect(hoveredVersion ? 1.25 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: hoveredVersion)
                    .onHover { hoveredVersion = $0 }
                    .help("Version \(AppTheme.version) · Build \(AppTheme.build)")
                    .padding(.trailing, 12)
            }
            .padding(.bottom, 6)
        }
        .background(AppTheme.sidebar)
        .onKeyPress(.escape) { renamingID = nil; return .handled }
        .sheet(isPresented: $showLibrary) {
            LibrarySheet(book: book, isPresented: $showLibrary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Library sheet

private struct LibrarySheet: View {
    let book: Book
    @Binding var isPresented: Bool
    @State private var recents: [RecentBook] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Library")
                    .font(AppTheme.editorialFont(20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(5)
                        .background(AppTheme.border.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider().background(AppTheme.border)

            if recents.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "books.vertical")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.3))
                    Text("No recent books yet")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Save a book to see it here")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 16)], spacing: 16) {
                        ForEach(recents) { recent in
                            LibraryCard(recent: recent) {
                                if let url = recent.url {
                                    book.load(from: url)
                                    isPresented = false
                                }
                            } onRemove: {
                                RecentBooksStore.shared.remove(recent)
                                recents = RecentBooksStore.shared.recents
                            }
                        }
                    }
                    .padding(20)
                }
            }

            Divider().background(AppTheme.border)

            // Footer
            HStack {
                Button {
                    book.open()
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text("Open Other File…")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.accentWrite)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 440)
        .background(AppTheme.background)
        .onAppear { recents = RecentBooksStore.shared.recents }
    }
}

private struct LibraryCard: View {
    let recent: RecentBook
    let onOpen: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Book cover mockup
            ZStack(alignment: .topTrailing) {
                // Gradient backdrop representing book cover
                LinearGradient(
                    colors: [
                        AppTheme.accentWrite.opacity(0.15),
                        AppTheme.accentWrite.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                // Centered book icon and details representation
                VStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.accentWrite)
                        .shadow(color: AppTheme.accentWrite.opacity(0.3), radius: 4, y: 2)

                    if !recent.exists {
                        Text("MISSING")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.8), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Hover delete button
                if isHovered {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(4)
                            .background(AppTheme.surface.opacity(0.9), in: Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                            .help("Remove this book from your recents list")
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .transition(.opacity)
                }
            }
            .background(AppTheme.border.opacity(0.1))

            Divider().background(AppTheme.border)

            // Metadata section
            VStack(alignment: .leading, spacing: 4) {
                Text(recent.title.isEmpty ? (recent.url?.deletingPathExtension().lastPathComponent ?? "Untitled") : recent.title)
                    .font(AppTheme.editorialFont(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .topLeading)

                Text(recent.author.isEmpty ? "Unknown Author" : recent.author)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)

                Text(recent.savedDate, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
            }
            .padding(10)
        }
        .editorialCard(cornerRadius: 10)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .glowingBorder(color: AppTheme.accentWrite.opacity(0.4), active: isHovered, radius: 6)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture { if recent.exists { onOpen() } }
        .onHover { isHovered = $0 }
        .opacity(recent.exists ? 1.0 : 0.6)
        .help("Double-click or press to open \(recent.title)")
    }
}

// MARK: - Feature dot

private struct FeatureDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
    }
}

// MARK: - Sidebar row

private struct SidebarItem: View {
    var symbol: String? = nil
    var emoji: String? = nil
    let label: String
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renameText: String
    var chapterStatus: ChapterStatus? = nil
    var isChapter: Bool = false
    var wordCount: Int? = nil
    let onTap: () -> Void
    let onCommitRename: () -> Void
    @FocusState private var focused: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                if let sym = symbol {
                    Image(systemName: sym)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? AppTheme.accentWrite : AppTheme.textSecondary)
                        .frame(width: 18)
                } else if let em = emoji {
                    Text(em).font(.system(size: 13)).frame(width: 18)
                }

                if isRenaming {
                    TextField("", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .focused($focused)
                        .onSubmit(onCommitRename)
                } else {
                    Text(label)
                        .font(.system(size: 13, weight: isSelected ? .semibold : (isChapter ? .medium : .regular)))
                        .foregroundStyle(
                            isChapter
                                ? (isSelected ? AppTheme.accentWrite : AppTheme.textPrimary)
                                : (isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                        )
                        .lineLimit(1)
                }
                Spacer()

                if let wc = wordCount {
                    Text(wc >= 1000 ? String(format: "%.1fk", Double(wc) / 1000.0) : "\(wc)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary.opacity(isSelected ? 0.75 : 0.40))
                }

                if let status = chapterStatus {
                    Image(systemName: status.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(status.color)
                        .help(status.rawValue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if isSelected && isChapter {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.accentWrite.opacity(0.16),
                                        AppTheme.accentWrite.opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Rectangle()
                            .fill(AppTheme.accentWrite)
                            .frame(width: 3)
                            .clipShape(UnevenRoundedRectangle(
                                topLeadingRadius: 8,
                                bottomLeadingRadius: 8,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 0
                            ))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? AppTheme.sidebarSelected : (isHovered ? AppTheme.sidebarHover : Color.clear))
                }
            }
            .glowingBorder(color: AppTheme.accentWrite.opacity(0.25), active: isSelected && isChapter, radius: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onChange(of: isRenaming) { _, v in if v { focused = true } }
    }
}

// MARK: - Save button (labeled, shows unsaved state)

struct SaveButton: View {
    let book: Book

    private var savedLabel: String {
        guard let date = book.lastSavedAt else { return "Save" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Saved just now" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "Saved \(fmt.string(from: date))"
    }

    var body: some View {
        Button { book.save() } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 11, weight: .medium))
                Text(savedLabel)
            }
            .help("Save (⌘S)")
        }
        .buttonStyle(GhostToolButtonStyle())
    }
}

// MARK: - Icon toolbar button

struct IconToolButton: View {
    let icon: String; let tip: String; let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .help(tip)
        }
        .buttonStyle(GhostToolButtonStyle())
    }
}

// MARK: - Step badge (shared across panels)

struct StepBadge: View {
    let number: String
    let accent: Color

    var body: some View {
        ZStack {
            Circle().fill(accent.opacity(0.20)).frame(width: 28, height: 28)
            Circle().strokeBorder(accent.opacity(0.50), lineWidth: 1.5).frame(width: 28, height: 28)
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
        }
    }
}
