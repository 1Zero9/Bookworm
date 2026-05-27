import SwiftUI
import AppKit
import NaturalLanguage

// MARK: - Continuous multi-chapter write view

struct ContinuousWriteView: View {
    @Environment(Book.self) private var book
    @EnvironmentObject private var layout: LayoutStore
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
        let isEmail = book.formatMode == .email
        let isLetter = book.formatMode == .letter
        let colWidth: CGFloat = readingMode 
            ? (isLetter ? min(width, 640) : min(width, 740)) 
            : width
        
        VStack(spacing: 0) {
            if isEmail {
                // Email Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("To:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 60, alignment: .leading)
                        
                        Text("draft-outbox@bookworm.app")
                            .font(AppTheme.uiFont(13))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    Divider().background(AppTheme.border)
                    
                    HStack(spacing: 12) {
                        Text("Subject:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Email Subject", text: $chapter.title)
                            .textFieldStyle(.plain)
                            .font(AppTheme.uiFont(13))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .padding(16)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .padding(.horizontal, 48)
                .padding(.top, 32)
                .frame(width: colWidth)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // ── chapter divider ──
                chapterDivider(title: chapter.title, emoji: AppTheme.emoji(for: idx))
            }

            // ── auto-sizing text editor ──
            AutoSizingTextEditor(
                text: $chapter.rawText,
                availableWidth: colWidth,
                measuredHeight: Binding(
                    get: { heights[chapter.id] ?? 400 },
                    set: { heights[chapter.id] = $0 }
                ),
                focusMode: layout.focusMode,
                rhythmMode: false,
                formatMode: book.formatMode
            )
            .frame(width: colWidth)
            .frame(height: max(200, heights[chapter.id] ?? 400))
            .shadow(color: readingMode ? .black.opacity(0.04) : .clear, radius: 8, x: 0, y: 3)
            .frame(maxWidth: .infinity, alignment: .center)

            // ── chapter break gap ──
            Color.clear.frame(height: 48)
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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
                Text(emoji)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accentWrite)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }

            Text(title.uppercased())
                .font(AppTheme.editorialFont(13, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .tracking(1.4)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 560)
        }
        .padding(.horizontal, 48)
        .padding(.top, 40)
        .padding(.bottom, 24)
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
    var focusMode: Bool
    var rhythmMode: Bool
    var formatMode: BookFormatMode

    private static let placeholder =
        "Write your scene here — prose, dialogue, descriptions."

    func makeNSView(context: Context) -> AutoTextView {
        let tv = AutoTextView()
        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        
        let fontSize: CGFloat = (formatMode == .letter) ? 18 : 16
        tv.font = AppTheme.editorialNSFont(fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        if formatMode == .letter {
            paragraphStyle.lineSpacing = 10
            paragraphStyle.paragraphSpacing = 18
        } else {
            paragraphStyle.lineSpacing = 4
            paragraphStyle.paragraphSpacing = 8
        }
        tv.defaultParagraphStyle = paragraphStyle
        
        let bg: NSColor
        if formatMode == .letter {
            bg = NSColor.dynamic(
                light: NSColor(hex: "#FAF6EE"),
                dark:  NSColor(hex: "#1A1510")
            )
        } else {
            let standardBg = NSColor.dynamic(
                light: NSColor(hex: "#F7F6F3"),
                dark:  NSColor(hex: "#121826")
            )
            bg = focusMode ? standardBg : .textBackgroundColor
        }
        tv.backgroundColor = bg
        
        let textColor: NSColor
        if formatMode == .letter {
            textColor = NSColor.dynamic(
                light: NSColor(hex: "#2E2214"),
                dark:  NSColor(hex: "#F6EADA")
            )
        } else {
            textColor = focusMode
                ? NSColor.dynamic(light: NSColor(hex: "#1F2937"), dark: NSColor(hex: "#F3F4F6"))
                : .textColor
        }
        tv.textColor = textColor
        tv.insertionPointColor = textColor

        tv.drawsBackground = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 5
        
        let padX: CGFloat = (formatMode == .letter) ? 56 : (focusMode ? 48 : 40)
        let padY: CGFloat = (formatMode == .letter) ? 36 : (focusMode ? 28 : 20)
        tv.textContainerInset = NSSize(width: padX, height: padY)
        
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
            tv.textColor = textColor
            if rhythmMode {
                context.coordinator.applyRhythmHighlights(tv)
            }
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

        let bg: NSColor
        if formatMode == .letter {
            bg = NSColor.dynamic(
                light: NSColor(hex: "#FAF6EE"),
                dark:  NSColor(hex: "#1A1510")
            )
        } else {
            let standardBg = NSColor.dynamic(
                light: NSColor(hex: "#F7F6F3"),
                dark:  NSColor(hex: "#121826")
            )
            bg = focusMode ? standardBg : .textBackgroundColor
        }
        tv.backgroundColor = bg
        
        let textColor: NSColor
        if formatMode == .letter {
            textColor = NSColor.dynamic(
                light: NSColor(hex: "#2E2214"),
                dark:  NSColor(hex: "#F6EADA")
            )
        } else {
            textColor = focusMode
                ? NSColor.dynamic(light: NSColor(hex: "#1F2937"), dark: NSColor(hex: "#F3F4F6"))
                : .textColor
        }
        tv.textColor = textColor
        tv.insertionPointColor = textColor
        
        let padX: CGFloat = (formatMode == .letter) ? 56 : (focusMode ? 48 : 40)
        let padY: CGFloat = (formatMode == .letter) ? 36 : (focusMode ? 28 : 20)
        tv.textContainerInset = NSSize(width: padX, height: padY)

        let fontSize: CGFloat = (formatMode == .letter) ? 18 : 16
        let font = AppTheme.editorialNSFont(fontSize)

        // Handle Rhythm Mode changes
        let modeChanged = context.coordinator.lastRhythmMode != rhythmMode
        context.coordinator.lastRhythmMode = rhythmMode
        
        if rhythmMode {
            if modeChanged || !context.coordinator.isEditing {
                context.coordinator.applyRhythmHighlights(tv)
            }
        } else {
            if modeChanged {
                context.coordinator.clearRhythmHighlights(tv)
            }
        }

        guard !context.coordinator.isEditing else { return }
        if text.isEmpty && tv.textColor == .textColor {
            applyPlaceholder(tv)
            if rhythmMode {
                context.coordinator.clearRhythmHighlights(tv)
            }
        } else if !text.isEmpty && tv.string != text {
            tv.textColor = textColor
            tv.font = font
            tv.string = text
            tv.recomputeHeight()
            if rhythmMode {
                context.coordinator.applyRhythmHighlights(tv)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func applyPlaceholder(_ tv: NSTextView) {
        let fontSize: CGFloat = (formatMode == .letter) ? 18 : 16
        tv.textStorage?.setAttributedString(NSAttributedString(
            string: Self.placeholder,
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: AppTheme.editorialNSFont(fontSize)
            ]
        ))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoSizingTextEditor
        weak var textView: AutoTextView?
        var isEditing = false
        var lastRhythmMode: Bool? = nil

        init(_ parent: AutoSizingTextEditor) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            isEditing = true
            if tv.textColor == .placeholderTextColor {
                tv.string = ""
                
                let textColor: NSColor
                if parent.formatMode == .letter {
                    textColor = NSColor.dynamic(
                        light: NSColor(hex: "#2E2214"),
                        dark:  NSColor(hex: "#F6EADA")
                    )
                } else {
                    textColor = .textColor
                }
                tv.textColor = textColor
                let fontSize: CGFloat = (parent.formatMode == .letter) ? 18 : 16
                tv.font = AppTheme.editorialNSFont(fontSize)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? AutoTextView else { return }
            let oldText = parent.text
            let newText = tv.string
            parent.text = newText
            tv.recomputeHeight()

            if parent.rhythmMode {
                applyRhythmHighlights(tv)
            }

            if parent.focusMode {
                if newText.count > oldText.count {
                    let lastChar = newText.last
                    if lastChar == "\n" {
                        TypewriterAudioEngine.shared.playChime()
                    } else {
                        TypewriterAudioEngine.shared.playClick()
                    }
                }
                
                // Centered midpoint scroll-locking locking!
                // Make sure cursor stays visible in center of view
                tv.scrollRangeToVisible(tv.selectedRange())
            }
        }

        func textDidEndEditing(_ notification: Notification) { isEditing = false }

        // MARK: - Rhythm Highlights Engine
        
        func applyRhythmHighlights(_ tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let savedTypingAttributes = tv.typingAttributes
            
            storage.beginEditing()
            
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.backgroundColor, range: fullRange)
            
            let text = storage.string
            guard !text.isEmpty && text != AutoSizingTextEditor.placeholder else {
                storage.endEditing()
                var cleanAttrs = savedTypingAttributes
                cleanAttrs.removeValue(forKey: .backgroundColor)
                tv.typingAttributes = cleanAttrs
                return
            }
            
            let sentenceTokenizer = NLTokenizer(unit: .sentence)
            sentenceTokenizer.string = text
            
            sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                let sentenceString = String(text[range])
                
                let wordTokenizer = NLTokenizer(unit: .word)
                wordTokenizer.string = sentenceString
                
                var wordCount = 0
                wordTokenizer.enumerateTokens(in: sentenceString.startIndex..<sentenceString.endIndex) { _, _ in
                    wordCount += 1
                    return true
                }
                
                let nsRange = NSRange(range, in: text)
                
                if wordCount <= 8 {
                    storage.addAttribute(.backgroundColor, value: AppTheme.rhythmShortNS, range: nsRange)
                } else if wordCount > 20 {
                    storage.addAttribute(.backgroundColor, value: AppTheme.rhythmLongNS, range: nsRange)
                }
                
                return true
            }
            
            storage.endEditing()
            
            // Clean dynamic attributes to prevent background color leakage
            var cleanAttrs = savedTypingAttributes
            cleanAttrs.removeValue(forKey: .backgroundColor)
            tv.typingAttributes = cleanAttrs
        }
        
        func clearRhythmHighlights(_ tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let savedTypingAttributes = tv.typingAttributes
            
            storage.beginEditing()
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.backgroundColor, range: fullRange)
            storage.endEditing()
            
            var cleanAttrs = savedTypingAttributes
            cleanAttrs.removeValue(forKey: .backgroundColor)
            tv.typingAttributes = cleanAttrs
        }
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

// MARK: - Image preview popover (module-internal, used by WorldBibleView too)

struct ImagePreviewPopover: View {
    let image: NSImage
    let id: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 4) {
                Text("ID:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(id)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
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
