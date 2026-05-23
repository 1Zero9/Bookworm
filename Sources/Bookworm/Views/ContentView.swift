import SwiftUI

struct ContentView: View {
    @Environment(Book.self) private var book
    @StateObject private var tts = TTSManager()
    @StateObject private var layout = LayoutStore()
    @ObservedObject private var launchStore = LaunchStore.shared
    @State private var rightTab: RightTab = .book
    @State private var bookZoom: CGFloat = 1.0
    @State private var showingMergePopover = false

    enum RightTab { case book, narrate, publish }

    var body: some View {
        Group {
            if layout.focusMode {
                InputEditorView(
                    layout: layout,
                    rightTab: $rightTab,
                    showRight: $layout.showRight,
                    reviewMode: $layout.reviewMode
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    if launchStore.isSandboxActive {
                        HStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(hex: "#D97706"))
                                
                                Text("✦ SCRATCH CANVAS")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#D97706"))
                                    .tracking(1.0)
                                
                                Text("— Drafting freely without pressure. This sandbox is isolated in memory.")
                                    .font(AppTheme.uiFont(11))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                launchStore.exitToLauncher()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "house")
                                    Text("Home Screen")
                                }
                            }
                            .buttonStyle(SecondaryPillButtonStyle())
                            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                            
                            Button(role: .destructive, action: {
                                let alert = NSAlert()
                                alert.messageText = "Abandon Sandbox Draft?"
                                alert.informativeText = "Are you sure you want to discard this temporary draft? This action cannot be undone."
                                alert.addButton(withTitle: "Discard")
                                alert.addButton(withTitle: "Cancel")
                                alert.alertStyle = .critical
                                if alert.runModal() == .alertFirstButtonReturn {
                                    launchStore.cancelSandbox()
                                }
                            }) {
                                Text("Abandon Draft")
                                    .foregroundStyle(Color.red)
                            }
                            .buttonStyle(SecondaryPillButtonStyle())
                            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                            
                            Button(action: {
                                showingMergePopover = true
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Merge into Book")
                                }
                            }
                            .buttonStyle(PrimaryPillButtonStyle())
                            .fixedSize(horizontal: true, vertical: false)
                            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                            .popover(isPresented: $showingMergePopover, arrowEdge: .bottom) {
                                MergePopoverView(launchStore: launchStore) { chapterID in
                                    launchStore.mergeScratchProse(to: chapterID)
                                    showingMergePopover = false
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Color(NSColor.dynamic(
                            light: NSColor(hex: "#FEF3C7"),
                            dark:  NSColor(hex: "#1E1B15")
                        )))
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(AppTheme.border).frame(height: 1)
                        }
                    }

                    LayoutBar(layout: layout, rightTab: $rightTab)

                    HStack(spacing: 6) {
                        if layout.showSidebar {
                            SidebarView()
                                .frame(width: layout.sidebarWidth)
                                .glassPanel(cornerRadius: 12)
                                .padding(.vertical, 6)
                                .padding(.leading, 6)
                            
                            PanelDivider {
                                layout.sidebarWidth = min(300, max(180, layout.sidebarWidth + $0))
                            } onEnd: {
                                layout.persist()
                            }
                        }

                        if layout.showWrite {
                            Group {
                                switch layout.centerMode {
                                case .world:
                                    WorldBibleView()
                                case .corkboard:
                                    CorkboardView()
                                default:
                                    InputEditorView(
                                        layout: layout,
                                        rightTab: $rightTab,
                                        showRight: $layout.showRight,
                                        reviewMode: $layout.reviewMode
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .glassPanel(cornerRadius: 12)
                            .glowingBorder(color: AppTheme.dynamicGlowColor(for: layout.centerMode), active: true, radius: 8)
                            .padding(.vertical, 6)
                            .padding(.horizontal, layout.showSidebar ? 0 : 6)
                        }

                        if layout.showRight {
                            let fillsRest = !layout.showWrite
                            if !fillsRest {
                                PanelDivider {
                                    layout.rightWidth = max(280, layout.rightWidth - $0)
                                } onEnd: {
                                    layout.persist()
                                }
                            }
                            rightPanel(fillsRest: fillsRest)
                                .glassPanel(cornerRadius: 12)
                                .padding(.vertical, 6)
                                .padding(.trailing, 6)
                        }
                    }
                    .frame(maxHeight: .infinity)

                    PlaybackBar()
                        .frame(height: 60)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(tts)
        .environmentObject(layout)
        .background(AppTheme.background)
        .onAppear {
            if book.formatMode == .email || book.formatMode == .letter {
                layout.showSidebar = false
                layout.showRight = false
            }
        }
        .onChange(of: book.formatMode) { _, newMode in
            if newMode == .email || newMode == newMode { // Trick to satisfy onChange syntax
                if newMode == .email || newMode == .letter {
                    layout.showSidebar = false
                    layout.showRight = false
                }
            }
        }
    }

    // MARK: - Right panel

    @ViewBuilder
    private func rightPanel(fillsRest: Bool) -> some View {
        VStack(spacing: 0) {
            PanelHeader(
                step: rightTab == .narrate ? "3" : rightTab == .publish ? "4" : "2",
                label: rightTab == .narrate ? "AUDIOBOOK STUDIO"
                     : rightTab == .publish ? "PUBLISH"
                     : "BOOK VIEW",
                subtitle: rightTab == .narrate ? "experience your story narrated"
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
                }
            }

            Divider().background(AppTheme.border)

            switch rightTab {
            case .book:    BookPreviewView(zoom: bookZoom)
            case .narrate: AudiobookStudioView().background(AppTheme.surface)
            case .publish: PublishView()
            }
        }
        .frame(maxWidth: fillsRest ? .infinity : layout.rightWidth)
        .frame(minWidth: fillsRest ? 0 : 280)
        .frame(maxHeight: .infinity)
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button { bookZoom = max(0.5, (bookZoom * 4 - 1).rounded() / 4) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 16, height: 16)
                    .help("Zoom out")
            }
            .buttonStyle(.plain)

            TactileSlider(
                value: Binding(
                    get: { Double(bookZoom) },
                    set: { bookZoom = CGFloat($0) }
                ),
                range: 0.5...2.0,
                accentColor: AppTheme.accentWrite
            )
            .frame(width: 72)

            Button { bookZoom = min(2.0, (bookZoom * 4 + 1).rounded() / 4) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 16, height: 16)
                    .help("Zoom in")
            }
            .buttonStyle(.plain)

            Text("\(Int((bookZoom * 100).rounded()))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 34, alignment: .leading)
        }
        .padding(.leading, 6)
    }
}

// MARK: - Simplified togglable layout bar

private struct LayoutBar: View {
    @ObservedObject var layout: LayoutStore
    @Binding var rightTab: ContentView.RightTab

    var body: some View {
        HStack(spacing: 12) {
            // Group 1: Left Side Panel Toggle
            HStack(spacing: 4) {
                Button {
                    layout.toggleSidebar()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Sidebar")
                    }
                    .help("Toggle left chapters and library sidebar")
                }
                .buttonStyle(NavPillButtonStyle(isActive: layout.showSidebar, accent: AppTheme.success))
            }

            Divider()
                .frame(height: 16)
                .background(AppTheme.border)

            // Group 2: Mutually Exclusive Center Modes
            HStack(spacing: 4) {
                ForEach(CenterMode.allCases, id: \.self) { mode in
                    Button {
                        layout.toggleCenterMode(mode)
                        if mode == .review {
                            rightTab = .book
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(mode.rawValue)
                        }
                        .help(mode.helpText)
                    }
                    .buttonStyle(NavPillButtonStyle(isActive: layout.showWrite && layout.centerMode == mode, accent: AppTheme.success))
                }
            }

            Divider()
                .frame(height: 16)
                .background(AppTheme.border)

            // Group 3: Right Side Panel Toggle
            HStack(spacing: 4) {
                Button {
                    layout.toggleRightPanel()
                    if layout.showRight { rightTab = .book }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Book Preview")
                    }
                    .help("Toggle right book rendering, narration script & PDF publishing preview panel")
                }
                .buttonStyle(NavPillButtonStyle(isActive: layout.showRight, accent: AppTheme.success))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(AppTheme.sidebar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
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
                Text(label)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(NavPillButtonStyle(isActive: isActive, accent: accent))
    }
}

// MARK: - Merge Popover View

struct MergePopoverView: View {
    let launchStore: LaunchStore
    let onSelect: (UUID) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MERGE INTO CHAPTER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(1.0)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            Divider().background(AppTheme.border)
            
            ScrollView {
                VStack(spacing: 4) {
                    if let chapters = launchStore.primaryBookBackup?.chapters, !chapters.isEmpty {
                        ForEach(chapters) { chapter in
                            Button {
                                onSelect(chapter.id)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.accentWrite)
                                    Text(chapter.title)
                                        .font(AppTheme.uiFont(11.5))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.surface)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        }
                    } else {
                        Text("No chapters found in primary book.")
                            .font(AppTheme.uiFont(11))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(20)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 250, height: 200)
        .background(AppTheme.background)
    }
}
