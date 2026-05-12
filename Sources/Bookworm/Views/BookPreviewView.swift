import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Zoom environment key

private struct BookZoomKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var bookZoom: CGFloat {
        get { self[BookZoomKey.self] }
        set { self[BookZoomKey.self] = newValue }
    }
}

// MARK: - Root view

struct BookPreviewView: View {
    @Environment(Book.self) private var book
    var zoom: CGFloat = 1.0
    @State private var chapterTops: [UUID: CGFloat] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Scroll offset tracker
                GeometryReader { g in
                    Color.clear.preference(
                        key: BPScrollOffsetKey.self,
                        value: g.frame(in: .named("bpScroll")).minY
                    )
                }
                .frame(height: 0)

                CoverPage()

                ForEach(book.chapters) { chapter in
                    ChapterOpeningPage(chapter: chapter)
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: BPChapterTopKey.self,
                                    value: [chapter.id: g.frame(in: .named("bpScroll")).minY]
                                )
                            }
                        )

                    ForEach(chapter.images) { img in
                        IllustrationPage(bookImage: img)
                    }

                    if !chapter.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ProsePages(text: chapter.rawText)
                    }
                }

                if book.chapters.isEmpty {
                    EmptyCoverHint()
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
        }
        .coordinateSpace(name: "bpScroll")
        .background(Color(NSColor.dynamic(
            light: NSColor(hex: "#E8E4DD"),
            dark:  NSColor(hex: "#0F1218")
        )))
        .environment(\.bookZoom, zoom)
        .onPreferenceChange(BPScrollOffsetKey.self) { offset in
            updateVisible(viewportTop: -offset)
        }
        .onPreferenceChange(BPChapterTopKey.self) { tops in
            chapterTops = tops
        }
    }

    private func updateVisible(viewportTop: CGFloat) {
        guard let (id, _) = chapterTops
            .filter({ $0.value <= viewportTop + 120 })
            .max(by: { $0.value < $1.value })
        else { return }

        if book.visibleChapterID != id {
            withAnimation(.easeInOut(duration: 0.22)) {
                book.visibleChapterID = id
            }
        }
    }
}

private struct BPScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct BPChapterTopKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Page shell

private struct Page<Content: View>: View {
    @Environment(\.bookZoom) private var zoom
    var minHeight: CGFloat = 640
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: 520 * zoom)
        .frame(minHeight: minHeight * zoom)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Cover page

private struct CoverPage: View {
    @Environment(Book.self) private var book
    @Environment(\.bookZoom) private var zoom

    var body: some View {
        Page(minHeight: 720) {
            ZStack {
                if let cover = book.coverImage {
                    Image(nsImage: cover.nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    LinearGradient(
                        colors: [
                            Color(hex: "#1B2340"),
                            Color(hex: "#2D3F6B"),
                            Color(hex: "#1B2340")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 12 * zoom) {
                        Rectangle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 60 * zoom, height: 1)

                        Text(book.title.isEmpty ? "Untitled Novel" : book.title)
                            .font(.system(size: 34 * zoom, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                        Rectangle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 60 * zoom, height: 1)

                        if !book.author.isEmpty {
                            Text(book.author.uppercased())
                                .font(.system(size: 12 * zoom, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                                .tracking(3)
                        }
                    }
                    .padding(.horizontal, 48 * zoom)
                    .padding(.bottom, 56 * zoom)
                }

                if book.coverImage == nil {
                    VStack {
                        DropCoverTarget()
                        Spacer()
                    }
                    .padding(.top, 32 * zoom)
                }
            }
        }
    }
}

private struct DropCoverTarget: View {
    @Environment(Book.self) private var book
    @Environment(\.bookZoom) private var zoom
    @State private var isTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                isTargeted ? Color.white : Color.white.opacity(0.35),
                style: StrokeStyle(lineWidth: 1.5, dash: [6])
            )
            .frame(width: 140 * zoom, height: 90 * zoom)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                VStack(spacing: 6 * zoom) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20 * zoom))
                    Text("Drop cover art")
                        .font(.system(size: 11 * zoom))
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: $isTargeted) { providers in
                guard let p = providers.first else { return false }
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let img = NSImage(contentsOf: url) else { return }
                    DispatchQueue.main.async { book.coverImage = BookImage(nsImage: img, placement: .cover) }
                }
                return true
            }
    }
}

// MARK: - Chapter opening page

private struct ChapterOpeningPage: View {
    @Environment(\.bookZoom) private var zoom
    let chapter: Chapter

    var body: some View {
        Page(minHeight: 300) {
            VStack(spacing: 20 * zoom) {
                Spacer()

                Text("❧")
                    .font(.system(size: 28 * zoom))
                    .foregroundStyle(Color(hex: "#8B7355"))

                Text(chapter.title)
                    .font(.system(size: 28 * zoom, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#1A1814"))

                Rectangle()
                    .fill(Color(hex: "#8B7355").opacity(0.4))
                    .frame(width: 40 * zoom, height: 1)

                Spacer()
            }
            .padding(.horizontal, 60 * zoom)
            .padding(.vertical, 48 * zoom)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Illustration page

private struct IllustrationPage: View {
    @Environment(\.bookZoom) private var zoom
    let bookImage: BookImage

    var body: some View {
        Page(minHeight: 200) {
            VStack(spacing: 16 * zoom) {
                Image(nsImage: bookImage.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400 * zoom)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                if !bookImage.caption.isEmpty {
                    Text(bookImage.caption)
                        .font(.system(size: 11 * zoom, design: .serif).italic())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(40 * zoom)
        }
    }
}

// MARK: - Prose pages

private struct ProsePages: View {
    @Environment(\.bookZoom) private var zoom
    let text: String
    private let wordsPerPage = 300

    var pages: [[String]] {
        let paragraphs = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result: [[String]] = [[]]
        var wordCount = 0
        for para in paragraphs {
            let wc = para.split(separator: " ").count
            if wordCount + wc > wordsPerPage && !result.last!.isEmpty {
                result.append([])
                wordCount = 0
            }
            result[result.count - 1].append(para)
            wordCount += wc
        }
        return result.filter { !$0.isEmpty }
    }

    var body: some View {
        ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, page in
            Page {
                VStack(alignment: .leading, spacing: 16 * zoom) {
                    ForEach(Array(page.enumerated()), id: \.offset) { paraIndex, para in
                        Text(para)
                            .font(.system(size: 14 * zoom, design: .serif))
                            .lineSpacing(6 * zoom)
                            .foregroundStyle(Color(hex: "#1A1814"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, (pageIndex == 0 && paraIndex == 0) ? 0 : 24 * zoom)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 56 * zoom)
                .padding(.vertical, 52 * zoom)
            }
        }
    }
}

// MARK: - Empty state

private struct EmptyCoverHint: View {
    @Environment(\.bookZoom) private var zoom

    var body: some View {
        VStack(spacing: 16 * zoom) {
            Image(systemName: "book.closed")
                .font(.system(size: 40 * zoom))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
            Text("Your book will appear here")
                .font(AppTheme.editorialFont(18 * zoom, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Add a chapter and start writing")
                .font(.system(size: 13 * zoom))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(60 * zoom)
    }
}
