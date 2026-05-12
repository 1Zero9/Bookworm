import SwiftUI

struct ContentView: View {
    @Environment(Book.self) private var book
    @StateObject private var tts = TTSManager()
    @StateObject private var layout = LayoutStore()
    @State private var rightTab: RightTab = .book
    @State private var bookZoom: CGFloat = 1.0

    enum RightTab { case book, narrate, publish }

    var body: some View {
        VStack(spacing: 0) {
            LayoutBar(layout: layout, rightTab: $rightTab)

            HStack(spacing: 0) {
                if layout.showSidebar {
                    SidebarView()
                        .frame(width: layout.sidebarWidth)
                    PanelDivider {
                        layout.sidebarWidth = min(300, max(180, layout.sidebarWidth + $0))
                    } onEnd: {
                        layout.persist()
                    }
                }

                if layout.showWrite {
                    if layout.currentPreset == .world {
                        WorldBibleView()
                            .frame(maxWidth: .infinity)
                    } else {
                        InputEditorView(
                            rightTab: $rightTab,
                            showRight: $layout.showRight,
                            reviewMode: $layout.reviewMode
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                if layout.showRight {
                    let fillsAll = !layout.showWrite && !layout.showSidebar
                    if !fillsAll {
                        PanelDivider {
                            layout.rightWidth = max(280, layout.rightWidth - $0)
                        } onEnd: {
                            layout.persist()
                        }
                    }
                    rightPanel(fillsAll: fillsAll)
                }
            }
            .frame(maxHeight: .infinity)

            PlaybackBar()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(tts)
        .background(AppTheme.background)
    }

    // MARK: - Right panel

    @ViewBuilder
    private func rightPanel(fillsAll: Bool) -> some View {
        VStack(spacing: 0) {
            PanelHeader(
                step: rightTab == .narrate ? "3" : rightTab == .publish ? "4" : "2",
                label: rightTab == .narrate ? "NARRATE"
                     : rightTab == .publish ? "PUBLISH"
                     : "BOOK VIEW",
                subtitle: rightTab == .narrate ? "bring your story to life"
                        : rightTab == .publish ? "export your finished book"
                        : "preview your novel",
                accent: rightTab == .narrate ? AppTheme.accentNarrate
                      : rightTab == .publish ? AppTheme.accentPublish
                      : AppTheme.accentWrite
            ) {
                HStack(spacing: 4) {
                    PanelTab(label: "Book",    icon: "book",                tab: .book,    accent: AppTheme.accentWrite,   current: $rightTab)
                    PanelTab(label: "Narrate", icon: "mic",                 tab: .narrate, accent: AppTheme.accentNarrate, current: $rightTab)
                    PanelTab(label: "Publish", icon: "square.and.arrow.up", tab: .publish, accent: AppTheme.accentPublish, current: $rightTab)

                    if rightTab == .book {
                        zoomControls
                    }

                    if !fillsAll {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { layout.showRight = false }
                        } label: {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(6)
                                .background(AppTheme.border.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Hide panel")
                        .padding(.leading, 4)
                    }
                }
            }

            Divider().background(AppTheme.border)

            switch rightTab {
            case .book:    BookPreviewView(zoom: bookZoom)
            case .narrate: NarrationScriptView().background(AppTheme.surface)
            case .publish: PublishView()
            }
        }
        .frame(maxWidth: fillsAll ? .infinity : layout.rightWidth)
        .frame(minWidth: fillsAll ? 0 : 280)
        .frame(maxHeight: .infinity)
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button { bookZoom = max(0.5, (bookZoom * 4 - 1).rounded() / 4) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain).help("Zoom out")

            Slider(value: $bookZoom, in: 0.5...2.0).frame(width: 72)

            Button { bookZoom = min(2.0, (bookZoom * 4 + 1).rounded() / 4) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain).help("Zoom in")

            Text("\(Int((bookZoom * 100).rounded()))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 34, alignment: .leading)
        }
        .padding(.leading, 6)
    }
}

// MARK: - Layout preset bar

private struct LayoutBar: View {
    @ObservedObject var layout: LayoutStore
    @Binding var rightTab: ContentView.RightTab

    var body: some View {
        HStack(spacing: 3) {
            ForEach(LayoutPreset.allCases, id: \.self) { preset in
                Button { activate(preset) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: preset.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(preset.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(layout.currentPreset == preset ? .white : AppTheme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        layout.currentPreset == preset ? preset.accent : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
                .help(helpText(preset))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(AppTheme.sidebar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    private func activate(_ preset: LayoutPreset) {
        layout.apply(preset)
        if preset == .book || preset == .writeBook { rightTab = .book }
    }

    private func helpText(_ p: LayoutPreset) -> String {
        switch p {
        case .organise:  return "Sidebar focus — chapters list expanded"
        case .write:     return "Write only — no preview panel"
        case .writeBook: return "Write + Book preview side by side"
        case .redpen:    return "Red pen review mode"
        case .book:      return "Book preview at full width"
        case .world:     return "World Bible — genre, rules & character vault"
        }
    }
}

// MARK: - Draggable panel divider

struct PanelDivider: View {
    let onChange: (CGFloat) -> Void
    let onEnd: () -> Void
    @State private var hovering = false
    @State private var lastX: CGFloat = 0

    var body: some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(hovering ? AppTheme.accentWrite.opacity(0.55) : AppTheme.border)
                .frame(width: 1)
        }
        .frame(width: 6)
        .contentShape(Rectangle())
        .onHover { h in
            hovering = h
            if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let d = v.translation.width - lastX
                    lastX = v.translation.width
                    onChange(d)
                }
                .onEnded { _ in lastX = 0; onEnd() }
        )
    }
}

// MARK: - Shared panel header

struct PanelHeader<Trailing: View>: View {
    let step: String
    let label: String
    let subtitle: String
    let accent: Color
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            StepBadge(number: step, accent: accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tracking(1.0)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(AppTheme.background)
    }
}

// MARK: - Tab button

private struct PanelTab: View {
    let label: String
    let icon: String
    let tab: ContentView.RightTab
    let accent: Color
    @Binding var current: ContentView.RightTab
    var isActive: Bool { current == tab }

    var body: some View {
        Button { current = tab } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .medium))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(isActive ? accent : AppTheme.textSecondary)
            .background(isActive ? accent.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}
