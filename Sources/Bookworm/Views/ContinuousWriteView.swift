import SwiftUI
import AppKit

// MARK: - Continuous multi-chapter write view

struct ContinuousWriteView: View {
    @Environment(Book.self) private var book
    @AppStorage("bw.readingMode") private var readingMode = true
    @State private var heights:    [UUID: CGFloat] = [:]
    @State private var chapterTops: [UUID: CGFloat] = [:]
    @State private var suppressTracking = false

    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        // Viewport-relative scroll offset tracker
                        GeometryReader { g in
                            Color.clear.preference(
                                key: CWScrollOffsetKey.self,
                                value: g.frame(in: .named("cwScroll")).minY
                            )
                        }
                        .frame(height: 0)

                        ForEach(Array(book.chapters.enumerated()), id: \.element.id) { idx, chapter in
                            @Bindable var chapter = chapter
                            chapterBlock(chapter: chapter, idx: idx, width: outer.size.width)
                        }

                        Color.clear.frame(height: 80)
                    }
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "cwScroll")
                // Sidebar click → scroll write view to that chapter
                .onChange(of: book.selectedChapterID) { _, newID in
                    guard !suppressTracking, let id = newID else { return }
                    suppressTracking = true
                    withAnimation(.easeInOut(duration: 0.35)) {
                        scrollProxy.scrollTo(id, anchor: .top)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        suppressTracking = false
                    }
                }
            }
        }
        .onPreferenceChange(CWScrollOffsetKey.self) { offset in
            guard !suppressTracking else { return }
            updateVisible(viewportTop: -offset)
        }
        .onPreferenceChange(CWChapterTopKey.self) { tops in
            chapterTops = tops
            if !suppressTracking {
                // Recompute after layout settles
                DispatchQueue.main.async { updateVisible(viewportTop: -(chapterTops.values.min() ?? 0)) }
            }
        }
        .background(readingMode ? AppTheme.background : Color(NSColor.textBackgroundColor))
    }

    // MARK: - Chapter block

    @ViewBuilder
    private func chapterBlock(chapter: Chapter, idx: Int, width: CGFloat) -> some View {
        @Bindable var chapter = chapter
        let colWidth: CGFloat = readingMode ? min(width, 740) : width
        VStack(spacing: 0) {
            // ── chapter divider ──
            chapterDivider(title: chapter.title, emoji: AppTheme.emoji(for: idx))

            // ── auto-sizing text editor ──
            AutoSizingTextEditor(
                text: $chapter.rawText,
                availableWidth: colWidth,
                measuredHeight: Binding(
                    get: { heights[chapter.id] ?? 400 },
                    set: { heights[chapter.id] = $0 }
                )
            )
            .frame(width: colWidth)
            .frame(height: max(200, heights[chapter.id] ?? 400))
            .shadow(color: readingMode ? .black.opacity(0.06) : .clear, radius: 8, x: 0, y: 2)
            .frame(maxWidth: .infinity, alignment: .center)

            // ── image strip (if any) ──
            if !chapter.images.isEmpty {
                Divider().background(AppTheme.border)
                ChapterImageStrip(chapter: chapter)
                    .background(AppTheme.background)
            }

            // ── chapter break gap ──
            Color.clear.frame(height: 56)
        }
        .id(chapter.id)
        .background(
            GeometryReader { g in
                Color.clear.preference(
                    key: CWChapterTopKey.self,
                    value: [chapter.id: g.frame(in: .named("cwScroll")).minY]
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

    // MARK: - Scroll tracking

    private func updateVisible(viewportTop: CGFloat) {
        // Active chapter = the one whose top has just scrolled above the viewport
        // (largest chapterTop that is ≤ viewportTop + lookahead)
        let lookahead: CGFloat = 80
        guard let (id, _) = chapterTops
            .filter({ $0.value <= viewportTop + lookahead })
            .max(by: { $0.value < $1.value })
        else { return }

        if book.visibleChapterID != id {
            withAnimation(.easeInOut(duration: 0.22)) {
                book.visibleChapterID = id
            }
        }
    }
}

// MARK: - Auto-sizing NSTextView

struct AutoSizingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var availableWidth: CGFloat
    @Binding var measuredHeight: CGFloat

    private static let placeholder =
        "Write your scene here — prose, dialogue, descriptions.\n\nWhen you're ready, tap Convert to Script above."

    func makeNSView(context: Context) -> AutoTextView {
        let tv = AutoTextView()
        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.font = NSFont(name: "Georgia", size: 16) ?? .systemFont(ofSize: 16)
        tv.backgroundColor = .textBackgroundColor
        tv.drawsBackground = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 5
        tv.textContainerInset = NSSize(width: 40, height: 20)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.frame = NSRect(x: 0, y: 0, width: max(1, availableWidth), height: 400)
        tv.onHeightChange = { h in
            DispatchQueue.main.async { measuredHeight = h }
        }

        if text.isEmpty {
            applyPlaceholder(tv)
        } else {
            tv.string = text
            tv.textColor = .textColor
        }
        // Schedule initial height measurement after first layout pass.
        // (recomputeHeight is only triggered by textDidChange normally,
        //  so new views created by LazyVStack would stay at the default height.)
        DispatchQueue.main.async { tv.recomputeHeight() }
        return tv
    }

    func updateNSView(_ tv: AutoTextView, context: Context) {
        context.coordinator.parent = self

        if abs(tv.frame.width - availableWidth) > 2 {
            var f = tv.frame
            f.size.width = availableWidth
            tv.frame = f
            tv.recomputeHeight()
        }

        guard !context.coordinator.isEditing else { return }
        if text.isEmpty && tv.textColor == .textColor {
            applyPlaceholder(tv)
        } else if !text.isEmpty && tv.string != text {
            tv.textColor = .textColor
            tv.font = NSFont(name: "Georgia", size: 16) ?? .systemFont(ofSize: 16)
            tv.string = text
            tv.recomputeHeight()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func applyPlaceholder(_ tv: NSTextView) {
        tv.textStorage?.setAttributedString(NSAttributedString(
            string: Self.placeholder,
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont(name: "Georgia", size: 16) ?? NSFont.systemFont(ofSize: 16)
            ]
        ))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoSizingTextEditor
        weak var textView: AutoTextView?
        var isEditing = false

        init(_ parent: AutoSizingTextEditor) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            isEditing = true
            if tv.textColor == .placeholderTextColor {
                tv.string = ""
                tv.textColor = .textColor
                tv.font = NSFont(name: "Georgia", size: 16) ?? .systemFont(ofSize: 16)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? AutoTextView else { return }
            parent.text = tv.string
            tv.recomputeHeight()
        }

        func textDidEndEditing(_ notification: Notification) { isEditing = false }
    }
}

// MARK: - Auto-sizing NSTextView subclass

final class AutoTextView: NSTextView {
    var onHeightChange: ((CGFloat) -> Void)?

    func recomputeHeight() {
        guard let lm = layoutManager, let tc = textContainer else { return }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        let h = used.height + (textContainerInset.height * 2) + 40
        onHeightChange?(max(200, h))
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        guard let lm = layoutManager, let tc = textContainer else {
            return super.intrinsicContentSize
        }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: used.height + (textContainerInset.height * 2) + 40
        )
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
}

// MARK: - Image strip (shared from InputEditorView)

struct ChapterImageStrip: View {
    @Bindable var chapter: Chapter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 10) {
                Text("Images in this chapter:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.leading, 4)

                ForEach(chapter.images) { img in
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: img.nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 88, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                        Button { chapter.images.removeAll { $0.id == img.id } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.textSecondary, AppTheme.border)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -4)
                        .help("Remove image")
                    }
                }

                Text("(visible in Book Preview →)")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    .italic()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 90)
    }
}

// MARK: - Preference keys (file-private)

private struct CWScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct CWChapterTopKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
