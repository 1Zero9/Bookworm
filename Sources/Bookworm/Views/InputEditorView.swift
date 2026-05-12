import SwiftUI
import AppKit

struct InputEditorView: View {
    @Environment(Book.self) private var book
    @Binding var rightTab: ContentView.RightTab
    @Binding var showRight: Bool
    @Binding var reviewMode: Bool
    @AppStorage("bw.readingMode") private var readingMode = true

    // The chapter currently in the viewport (scroll-driven) or explicitly selected.
    private var activeChapter: Chapter? {
        let id = book.visibleChapterID ?? book.selectedChapterID
        return book.chapters.first { $0.id == id }
    }

    var body: some View {
        if reviewMode {
            EditReviewView(editMode: $reviewMode)
        } else {
            writeView
        }
    }

    @ViewBuilder
    private var writeView: some View {
        VStack(spacing: 0) {
            PanelHeader(
                step: "1",
                label: "WRITE",
                subtitle: activeChapter?.title ?? "Cover page",
                accent: AppTheme.accentWrite
            ) {
                HStack(spacing: 8) {
                    if !showRight {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showRight = true }
                        } label: {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.accentWrite)
                                .padding(6)
                                .background(AppTheme.accentWrite.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Show book preview panel")
                    }

                    Button { readingMode.toggle() } label: {
                        Image(systemName: "text.aligncenter")
                            .font(.system(size: 13))
                            .foregroundStyle(readingMode ? AppTheme.accentWrite : AppTheme.textSecondary)
                            .padding(7)
                            .background(
                                readingMode ? AppTheme.accentWrite.opacity(0.12) : AppTheme.border.opacity(0.6),
                                in: RoundedRectangle(cornerRadius: 7)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(readingMode ? "Switch to full-width layout" : "Switch to reading-width column")

                    if activeChapter != nil {
                        Button { insertImage() } label: {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(7)
                                .background(AppTheme.border.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .help("Insert image into current chapter")

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { reviewMode = true }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "pencil.line")
                                    .font(.system(size: 12))
                                Text("Red Pen")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color(NSColor.systemOrange))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(NSColor.systemOrange).opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .help("Switch to review/annotation mode")

                        let textEmpty = activeChapter?.rawText
                            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
                        Button {
                            guard let ch = activeChapter else { return }
                            ch.narrationScript = ScriptConverter.convert(ch.rawText)
                            rightTab = .narrate
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 12))
                                Text("Convert to Script")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentWrite, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(textEmpty)
                        .opacity(textEmpty ? 0.4 : 1)
                    }
                }
            }

            Divider().background(AppTheme.border)

            // Show continuous write view when chapters exist, cover editor otherwise.
            if book.selectedChapterID != nil || !book.chapters.isEmpty {
                ContinuousWriteView()
                    .background(AppTheme.surface)
            } else {
                CoverEditorView()
                    .background(AppTheme.surface)
            }
        }
    }

    private func insertImage() {
        guard let chapter = activeChapter else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              let img = NSImage(contentsOf: url) else { return }
        chapter.images.append(BookImage(nsImage: img))
    }
}

// MARK: - NSTextView wrapper (kept for EditReviewView / AnnotatedTextEditor use)

struct RawTextEditor: NSViewRepresentable {
    @Binding var text: String
    var bgColor: NSColor = .textBackgroundColor

    private static let placeholder =
        "Write your scene here — prose, dialogue, descriptions.\n\nWhen you're ready, tap Convert to Script above."

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let tv = scrollView.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.font = NSFont(name: "Georgia", size: 16) ?? .systemFont(ofSize: 16)
        tv.drawsBackground = true
        tv.backgroundColor = bgColor
        scrollView.backgroundColor = bgColor
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainerInset = NSSize(width: 40, height: 36)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        if text.isEmpty { applyPlaceholder(tv) } else { tv.string = text; tv.textColor = .textColor }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let tv = nsView.documentView as! NSTextView
        guard !context.coordinator.isEditing else { return }
        if text.isEmpty && tv.textColor == .textColor {
            applyPlaceholder(tv)
        } else if !text.isEmpty && tv.string != text {
            tv.textColor = .textColor
            tv.font = NSFont(name: "Georgia", size: 16) ?? .systemFont(ofSize: 16)
            tv.string = text
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
        var parent: RawTextEditor
        var isEditing = false
        init(_ parent: RawTextEditor) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            isEditing = true
            if tv.textColor == .placeholderTextColor {
                tv.string = ""; tv.textColor = .textColor
                tv.font = NSFont(name: "Georgia", size: 16) ?? .systemFont(ofSize: 16)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textDidEndEditing(_ notification: Notification) { isEditing = false }
    }
}
