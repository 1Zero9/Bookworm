import SwiftUI
import AppKit

struct InputEditorView: View {
    @Environment(Book.self) private var book
    @ObservedObject var layout: LayoutStore
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
            if layout.focusMode {
                ZStack(alignment: .topTrailing) {
                    ContinuousWriteView()
                        .background(AppTheme.background)

                    FocusModeExitButton(layout: layout)
                        .padding(24)
                }
            } else {
                writeView
            }
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
                    Button { readingMode.toggle() } label: {
                        Image(systemName: "text.aligncenter")
                            .help(readingMode ? "Switch to full-width layout" : "Switch to reading-width column")
                    }
                    .buttonStyle(NavPillButtonStyle(isActive: readingMode, accent: AppTheme.accentWrite))

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            layout.focusMode = true
                        }
                    } label: {
                        Image(systemName: "eye.slash")
                            .help("Enter Zen Focus Mode")
                    }
                    .buttonStyle(GhostToolButtonStyle())

                }
            }

            Divider().background(AppTheme.border)

            // Show continuous write view when chapters exist, cover editor otherwise.
            if book.selectedChapterID != nil || !book.chapters.isEmpty {
                ContinuousWriteView()
                    .frame(maxWidth: .infinity)
                .background(AppTheme.surface)
            } else {
                CoverEditorView()
                    .background(AppTheme.surface)
            }
        }
    }

}

// MARK: - Focus Mode Exit Button Overlay

private struct FocusModeExitButton: View {
    @ObservedObject var layout: LayoutStore
    @State private var hovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                layout.focusMode = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11))
                Text("Exit Focus")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(hovered ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.surface.opacity(hovered ? 0.95 : 0.65), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(hovered ? 0.15 : 0.04), radius: hovered ? 8 : 3, y: 1)
            .help("Exit Zen Focus Mode and restore navigation layouts")
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovered)
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
