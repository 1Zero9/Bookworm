import SwiftUI

struct SidebarView: View {
    @Environment(Book.self) private var book
    @State private var renamingID: UUID? = nil
    @State private var renameText: String = ""
    @State private var showLibrary = false
    @State private var showSettings = false

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
                            .clipShape(RoundedRectangle(cornerRadius: 7))
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
                                chapterStatus: chapter.status
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
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text("New Chapter").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppTheme.accentWrite, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .help("Add a new chapter")

            HStack {
                Button { showSettings = true } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Spacer()

                Text("Bookworm \(AppTheme.version)")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                    .padding(.trailing, 10)
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
                    .font(AppTheme.editorialFont(18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
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
                    VStack(spacing: 4) {
                        ForEach(recents) { recent in
                            LibraryRow(recent: recent) {
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
                    .padding(16)
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
        .frame(width: 460, height: 420)
        .background(AppTheme.background)
        .onAppear { recents = RecentBooksStore.shared.recents }
    }
}

private struct LibraryRow: View {
    let recent: RecentBook
    let onOpen: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.accentWrite.opacity(0.8))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(recent.title.isEmpty ? (recent.url?.deletingPathExtension().lastPathComponent ?? "Untitled") : recent.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !recent.author.isEmpty {
                        Text(recent.author)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text(recent.savedDate, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                    if !recent.exists {
                        Text("Missing")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.7))
                    }
                }
            }

            Spacer()

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(5)
                        .background(AppTheme.border.opacity(0.8), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Remove from library")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHovered ? AppTheme.sidebarHover : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { if recent.exists { onOpen() } }
        .onHover { isHovered = $0 }
        .opacity(recent.exists ? 1.0 : 0.5)
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
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()

                if let status = chapterStatus {
                    Image(systemName: status.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(status.color)
                        .help(status.rawValue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? AppTheme.sidebarSelected
                    : (isHovered ? AppTheme.sidebarHover : Color.clear),
                in: RoundedRectangle(cornerRadius: 8)
            )
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
    @State private var isHovered = false

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
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isHovered ? AppTheme.accentWrite : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isHovered ? AppTheme.accentWrite.opacity(0.12) : AppTheme.border.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
        .help("Save (⌘S)")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Icon toolbar button

struct IconToolButton: View {
    let icon: String; let tip: String; let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isHovered ? AppTheme.textPrimary : AppTheme.textSecondary)
                .padding(7)
                .background(
                    AppTheme.border.opacity(isHovered ? 1.2 : 0.6),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
        .help(tip)
        .onHover { isHovered = $0 }
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
