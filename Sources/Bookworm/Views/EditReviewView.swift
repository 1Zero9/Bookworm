import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Helper types

private struct PendingAnnotation: Identifiable {
    let id    = UUID()
    let chapter: Chapter
    let range:   NSRange
}

struct RedPenScrollRequest {
    let chapterID: UUID
    let nonce     = UUID()
}

// MARK: - Top-level view

struct EditReviewView: View {
    @Environment(Book.self) private var book
    @Binding var editMode: Bool

    @State private var activeChapterID:       UUID?    = nil
    @State private var selectedRange:         NSRange? = nil
    @State private var selectedChapterForRange: UUID?  = nil
    @State private var pendingAnnotation: PendingAnnotation? = nil
    @State private var scrollRequest:    RedPenScrollRequest? = nil
    @State private var isAuditing   = false
    @State private var auditError:   String? = nil
    @State private var showAuditError = false

    private static let accent = Color(NSColor.systemOrange)

    private var activeChapter: Chapter? {
        let id = activeChapterID ?? book.chapters.first?.id
        return book.chapters.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            reviewHeader
            Divider().background(AppTheme.border)
            HStack(spacing: 0) {
                ContinuousAnnotatedView(
                    activeChapterID:    $activeChapterID,
                    selectedRange:      $selectedRange,
                    selectedChapterID:  $selectedChapterForRange,
                    scrollRequest:      scrollRequest
                )
                Divider().background(AppTheme.border)
                if let chapter = activeChapter {
                    @Bindable var chapter = chapter
                    AnnotationsSidebar(chapter: chapter) { ann in
                        scrollRequest = RedPenScrollRequest(chapterID: chapter.id)
                    }
                    .frame(width: 260)
                }
            }
        }
        .sheet(item: $pendingAnnotation) { pending in
            AddNoteSheet(range: pending.range, text: pending.chapter.rawText) { note, tag in
                pending.chapter.annotations.append(Annotation(
                    start: pending.range.location,
                    end:   pending.range.location + pending.range.length,
                    note:  note,
                    tag:   tag
                ))
                pending.chapter.annotations.sort { $0.start < $1.start }
            }
        }
        .alert("AI Audit Error", isPresented: $showAuditError) {
            Button("OK") {}
        } message: {
            Text(auditError ?? "Unknown error")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var reviewHeader: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { editMode = false }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    Text("Write").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Self.accent)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Self.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Back to Write mode")

            Text("RED PEN")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .tracking(1.0)

            Text("·").foregroundStyle(AppTheme.textSecondary)

            Text(activeChapter?.title ?? "")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            if AppSettings.shared.hasApiKey, let chapter = activeChapter {
                Button { runAudit(chapter: chapter) } label: {
                    HStack(spacing: 5) {
                        if isAuditing {
                            ProgressView().scaleEffect(0.7).frame(width: 11, height: 11)
                        } else {
                            Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold))
                        }
                        Text(isAuditing ? "Analysing…" : "AI Audit").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppTheme.accentWorld, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(isAuditing || chapter.rawText.isEmpty)
                .opacity((isAuditing || chapter.rawText.isEmpty) ? 0.55 : 1)
                .help("Ask Gemini to flag clichés, wiki-voice & emotional gaps")
            }

            Button {
                guard let range = selectedRange,
                      let chapter = book.chapters.first(where: { $0.id == selectedChapterForRange })
                else { return }
                pendingAnnotation = PendingAnnotation(chapter: chapter, range: range)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text("Add Note").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5)
                .background(selectedRange != nil ? Self.accent : Self.accent.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(selectedRange == nil)
            .help("Select text first, then add a note")

            if let chapter = activeChapter {
                Button { exportMarkdown(chapter: chapter) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.doc").font(.system(size: 11))
                        Text("Export MD").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.textSecondary).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppTheme.border.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(chapter.annotations.isEmpty)
                .opacity(chapter.annotations.isEmpty ? 0.4 : 1)
                .help("Export annotated text as Markdown")

                if !chapter.annotations.isEmpty {
                    Button { chapter.annotations.removeAll() } label: {
                        Image(systemName: "trash").font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary).padding(6)
                            .background(AppTheme.border.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain).help("Clear all notes for this chapter")
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(AppTheme.background)
    }

    // MARK: - AI Audit

    private func runAudit(chapter: Chapter) {
        isAuditing = true
        let prompt = ContextManager.narrativeAuditPrompt(for: chapter, book: book)
        Task {
            do {
                let raw   = try await GeminiClient.shared.generate(prompt: prompt)
                let items = try ContextManager.parseAuditResponse(raw)
                await MainActor.run {
                    ContextManager.applyAuditToChapter(items, chapter: chapter)
                    isAuditing = false
                }
            } catch {
                await MainActor.run {
                    auditError     = error.localizedDescription
                    showAuditError = true
                    isAuditing     = false
                }
            }
        }
    }

    // MARK: - Export

    private func exportMarkdown(chapter: Chapter) {
        let md = buildMarkdown(chapter: chapter)
        let panel = NSSavePanel()
        panel.title = "Export Edit Notes"
        panel.allowedContentTypes = [UTType.plainText]
        panel.nameFieldStringValue = "\(chapter.title) - Edit Notes"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try md.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert(); alert.messageText = "Could not export: \(error.localizedDescription)"; alert.runModal()
        }
    }

    private func buildMarkdown(chapter: Chapter) -> String {
        let ns = chapter.rawText as NSString
        let sorted = chapter.annotations.sorted { $0.start < $1.start }
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        var out = "# \(chapter.title) — Edit Notes\n\n_Exported \(date)_\n\n---\n\n## Annotated Text\n\n"
        var cursor = 0
        for (i, ann) in sorted.enumerated() {
            let loc = min(ann.start, ns.length)
            let len = min(ann.end - ann.start, ns.length - loc)
            guard len > 0, loc >= cursor else { continue }
            out += ns.substring(with: NSRange(location: cursor, length: loc - cursor))
            out += "==\(ns.substring(with: NSRange(location: loc, length: len)))==`[\(i + 1)]`"
            cursor = loc + len
        }
        out += ns.substring(from: cursor)
        out += "\n\n---\n\n## Notes\n\n"
        for (i, ann) in sorted.enumerated() {
            let loc = min(ann.start, ns.length); let len = min(ann.end - ann.start, ns.length - loc)
            guard len > 0 else { continue }
            let snippet = ns.substring(with: NSRange(location: loc, length: min(len, 60)))
            out += "**[\(i + 1)] \(ann.tag.rawValue)** — _\"\(snippet)\(len > 60 ? "…" : "")\"_\n\n"
            if !ann.note.isEmpty { out += "> \(ann.note)\n\n" }
        }
        return out
    }
}

// MARK: - Continuous annotated scroll view

private struct ContinuousAnnotatedView: View {
    @Environment(Book.self) private var book
    @Binding var activeChapterID:   UUID?
    @Binding var selectedRange:     NSRange?
    @Binding var selectedChapterID: UUID?
    var scrollRequest: RedPenScrollRequest?

    @AppStorage("bw.readingMode") private var readingMode = true
    @State private var heights:      [UUID: CGFloat] = [:]
    @State private var chapterTops:  [UUID: CGFloat] = [:]
    @State private var suppressTracking = false
    @State private var lastScrollNonce: UUID? = nil

    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        GeometryReader { g in
                            Color.clear.preference(
                                key: RPScrollOffsetKey.self,
                                value: g.frame(in: .named("rpScroll")).minY
                            )
                        }
                        .frame(height: 0)

                        ForEach(Array(book.chapters.enumerated()), id: \.element.id) { idx, chapter in
                            chapterBlock(chapter: chapter, idx: idx, width: outer.size.width)
                        }

                        Color.clear.frame(height: 80)
                    }
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "rpScroll")
                .onChange(of: scrollRequest?.nonce) { _, nonce in
                    guard let nonce, nonce != lastScrollNonce, let req = scrollRequest else { return }
                    lastScrollNonce = nonce
                    suppressTracking = true
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(req.chapterID, anchor: .top) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { suppressTracking = false }
                }
            }
        }
        .onPreferenceChange(RPScrollOffsetKey.self) { offset in
            guard !suppressTracking else { return }
            updateVisible(viewportTop: -offset)
        }
        .onPreferenceChange(RPChapterTopKey.self) { tops in
            chapterTops = tops
        }
        .background(readingMode ? AppTheme.background : Color(NSColor.textBackgroundColor))
    }

    @ViewBuilder
    private func chapterBlock(chapter: Chapter, idx: Int, width: CGFloat) -> some View {
        let colWidth: CGFloat = readingMode ? min(width, 740) : width
        VStack(spacing: 0) {
            chapterDivider(title: chapter.title, emoji: AppTheme.emoji(for: idx))

            AutoAnnotatedTextEditor(
                text:           chapter.rawText,
                annotations:    chapter.annotations,
                chapterID:      chapter.id,
                availableWidth: colWidth,
                measuredHeight: Binding(
                    get: { heights[chapter.id] ?? 400 },
                    set: { heights[chapter.id] = $0 }
                ),
                onSelectionChange: { chID, range in
                    selectedRange = range
                    if range != nil { selectedChapterID = chID }
                }
            )
            .frame(width: colWidth)
            .frame(height: max(200, heights[chapter.id] ?? 400))
            .shadow(color: readingMode ? .black.opacity(0.06) : .clear, radius: 8, x: 0, y: 2)
            .frame(maxWidth: .infinity, alignment: .center)

            Color.clear.frame(height: 56)
        }
        .id(chapter.id)
        .background(
            GeometryReader { g in
                Color.clear.preference(
                    key: RPChapterTopKey.self,
                    value: [chapter.id: g.frame(in: .named("rpScroll")).minY]
                )
            }
        )
    }

    @ViewBuilder
    private func chapterDivider(title: String, emoji: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
        .padding(.horizontal, 48)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .background(AppTheme.background)
    }

    private func updateVisible(viewportTop: CGFloat) {
        let lookahead: CGFloat = 80
        guard let (id, _) = chapterTops
            .filter({ $0.value <= viewportTop + lookahead })
            .max(by: { $0.value < $1.value })
        else { return }
        if activeChapterID != id {
            withAnimation(.easeInOut(duration: 0.22)) { activeChapterID = id }
        }
    }
}

// MARK: - Auto-sizing read-only annotated text view

private struct AutoAnnotatedTextEditor: NSViewRepresentable {
    let text:        String
    let annotations: [Annotation]
    let chapterID:   UUID
    var availableWidth: CGFloat
    @Binding var measuredHeight: CGFloat
    var onSelectionChange: (UUID, NSRange?) -> Void = { _, _ in }

    func makeNSView(context: Context) -> AutoTextView {
        let tv = AutoTextView()
        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        tv.isRichText = false
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = NSFont(name: "Georgia", size: 16) ?? .systemFont(ofSize: 16)
        tv.backgroundColor = .textBackgroundColor
        tv.drawsBackground = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 5
        tv.textContainerInset = NSSize(width: 40, height: 36)
        tv.frame = NSRect(x: 0, y: 0, width: max(1, availableWidth), height: 400)
        tv.onHeightChange = { h in DispatchQueue.main.async { measuredHeight = h } }
        tv.string = text
        applyHighlights(to: tv)
        DispatchQueue.main.async { tv.recomputeHeight() }
        return tv
    }

    func updateNSView(_ tv: AutoTextView, context: Context) {
        context.coordinator.parent = self
        if abs(tv.frame.width - availableWidth) > 2 {
            var f = tv.frame; f.size.width = availableWidth; tv.frame = f
            tv.recomputeHeight()
        }
        if tv.string != text { tv.string = text; tv.recomputeHeight() }
        applyHighlights(to: tv)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func applyHighlights(to tv: AutoTextView) {
        guard let storage = tv.textStorage, storage.length > 0 else { return }
        let font = NSFont(name: "Georgia", size: 17) ?? .systemFont(ofSize: 17)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 5
        para.paragraphSpacing = 14
        para.paragraphSpacingBefore = 0
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: full)
        storage.addAttribute(.font,             value: font,                    range: full)
        storage.addAttribute(.foregroundColor,  value: NSColor.textColor,       range: full)
        storage.addAttribute(.paragraphStyle,   value: para,                    range: full)
        for ann in annotations {
            let loc = min(ann.start, storage.length)
            let len = min(ann.end - ann.start, storage.length - loc)
            guard len > 0 else { continue }
            storage.addAttribute(.backgroundColor, value: ann.tag.nsColor,
                                 range: NSRange(location: loc, length: len))
        }
        storage.endEditing()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoAnnotatedTextEditor
        weak var textView: AutoTextView?

        init(_ parent: AutoAnnotatedTextEditor) { self.parent = parent }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let range = tv.selectedRange()
            DispatchQueue.main.async {
                self.parent.onSelectionChange(self.parent.chapterID, range.length > 0 ? range : nil)
            }
        }
    }
}

// MARK: - Preference keys

private struct RPScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct RPChapterTopKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Annotations sidebar

private struct AnnotationsSidebar: View {
    @Bindable var chapter: Chapter
    let onSelect: (Annotation) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if !chapter.annotations.isEmpty {
                    Text("\(chapter.annotations.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(AppTheme.background)

            Divider().background(AppTheme.border)

            if chapter.annotations.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "pencil.and.ruler")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                    Text("Select text, then tap\n\"Add Note\" to annotate")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(chapter.annotations) { ann in
                            AnnotationRow(
                                annotation: ann,
                                rawText: chapter.rawText,
                                onSelect: { onSelect(ann) },
                                onDelete: { chapter.annotations.removeAll { $0.id == ann.id } }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
                .background(AppTheme.background)
            }
        }
    }
}

private struct AnnotationRow: View {
    let annotation: Annotation
    let rawText: String
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var hovered = false

    private var snippet: String {
        let ns = rawText as NSString
        let loc = min(annotation.start, ns.length)
        let len = min(annotation.end - annotation.start, ns.length - loc)
        guard len > 0 else { return "" }
        return ns.substring(with: NSRange(location: loc, length: min(len, 80)))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(annotation.tag.color).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: annotation.tag.icon)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(annotation.tag.color)
                    Text(annotation.tag.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(annotation.tag.color)
                        .tracking(0.5)
                    Spacer()
                    if hovered {
                        Button { onDelete() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove this note")
                    }
                }
                if !snippet.isEmpty {
                    Text("\"\(snippet)\(annotation.end - annotation.start > 80 ? "…" : "")\"")
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2).italic()
                }
                if !annotation.note.isEmpty {
                    Text(annotation.note)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .background(hovered ? AppTheme.sidebarHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onSelect() }
    }
}

// MARK: - Add note sheet

private struct AddNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let range: NSRange?
    let text:  String
    let onAdd: (String, AnnotationTag) -> Void

    @State private var note = ""
    @State private var tag: AnnotationTag = .note

    private var snippet: String {
        guard let range, let str = (text as NSString?) else { return "" }
        let loc = min(range.location, str.length)
        let len = min(range.length, str.length - loc)
        guard len > 0 else { return "" }
        return str.substring(with: NSRange(location: loc, length: min(len, 120)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if !snippet.isEmpty {
                Text("\"\(snippet)\(range.map { $0.length > 120 ? "…" : "" } ?? "")\"")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3).italic().padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.border.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 6) {
                ForEach(AnnotationTag.allCases, id: \.self) { t in
                    Button { tag = t } label: {
                        HStack(spacing: 4) {
                            Image(systemName: t.icon).font(.system(size: 9, weight: .medium))
                            Text(t.rawValue).font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(tag == t ? .white : AppTheme.textSecondary)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(tag == t ? t.color : AppTheme.border.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Your note (optional)…", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .font(.system(size: 12))

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .foregroundStyle(AppTheme.textSecondary)
                Button("Add Note") { onAdd(note, tag); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(tag.color)
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(AppTheme.surface)
    }
}
