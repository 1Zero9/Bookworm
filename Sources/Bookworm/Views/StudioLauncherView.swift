import SwiftUI
import AppKit

struct StudioLauncherView: View {
    @ObservedObject var launchStore: LaunchStore = .shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var recentBooks: [RecentBook] = []
    @State private var hoveredCard: BookFormatMode? = nil
    @State private var hoverSandbox = false

    var body: some View {
        HStack(spacing: 0) {
            // LEFT PANEL: Recent Projects Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Header Title
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accentWrite, AppTheme.accentWorld],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Library")
                        .font(AppTheme.editorialFont(14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Recents List
                ScrollView {
                    VStack(spacing: 8) {
                        if recentBooks.isEmpty {
                            // Redesigned gorgeous floating manuscript empty state
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.accentWrite.opacity(0.06))
                                        .frame(width: 64, height: 64)
                                        .blur(radius: 8)
                                    
                                    // Manuscript sheet 1
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(AppTheme.surface)
                                        .frame(width: 24, height: 34)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .stroke(AppTheme.border, lineWidth: 1)
                                        )
                                        .rotationEffect(.degrees(-12))
                                        .offset(x: -8, y: 4)
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04), radius: 2)
                                    
                                    // Manuscript sheet 2
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(AppTheme.surface)
                                        .frame(width: 26, height: 36)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .stroke(AppTheme.border, lineWidth: 1)
                                        )
                                        .rotationEffect(.degrees(6))
                                        .offset(x: 8, y: -2)
                                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 3)
                                    
                                    Image(systemName: "feather.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.accentWrite)
                                        .offset(x: 10, y: 10)
                                }
                                .frame(height: 80)
                                
                                VStack(spacing: 4) {
                                    Text("Your Library is Quiet")
                                        .font(AppTheme.editorialFont(13, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("Begin a new manuscript or load an existing file to see your recent drafts here.")
                                        .font(AppTheme.uiFont(10.5))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                        .lineSpacing(2)
                                }
                            }
                            .padding(.top, 48)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(recentBooks) { recent in
                                RecentItemRow(recent: recent) {
                                    if let url = recent.url {
                                        launchStore.loadBook(url: url)
                                    }
                                } onDelete: {
                                    RecentBooksStore.shared.remove(recent)
                                    recentBooks = RecentBooksStore.shared.recents
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                }
                
                Spacer()
                
                Divider().background(AppTheme.border.opacity(0.4))
                
                // Sidebar Footer: Version details & Actions
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.success.opacity(0.8))
                            .frame(width: 5, height: 5)
                        Text("Bookworm \(AppTheme.version)")
                            .font(AppTheme.editorialFont(9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.border.opacity(0.25), in: Capsule())
                    
                    Spacer()
                    
                    if !recentBooks.isEmpty {
                        Button {
                            recentBooks.forEach { RecentBooksStore.shared.remove($0) }
                            recentBooks = []
                        } label: {
                            Text("Clear Recents")
                                .font(AppTheme.editorialFont(9.5, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.border.opacity(0.2), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(width: 280)
            .background(AppTheme.sidebar)
            
            Divider().background(AppTheme.border.opacity(0.6))
            
            // RIGHT PANEL: Studio Greeting & Specialized Templates Grid
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    
                    // Greetings Segment with soft radial glow background
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.accentWrite)
                            Text("STUDIO WELCOME")
                                .font(AppTheme.editorialFont(10, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .tracking(2.5)
                        }
                        
                        Text("Establish Your Focus")
                            .font(AppTheme.editorialFont(32, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text("Select a specialized workspace structure to begin drafting, or choose a sandboxed scratchpad to overcome writer's block.")
                            .font(AppTheme.uiFont(13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(4)
                            .lineLimit(nil)
                            .frame(maxWidth: 580, alignment: .leading)
                    }
                    .padding(.top, 44)
                    .background(
                        RadialGradient(
                            colors: [AppTheme.accentWrite.opacity(colorScheme == .dark ? 0.05 : 0.03), Color.clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 280
                        )
                        .offset(x: -40, y: -40)
                        .allowsHitTesting(false)
                    )
                    
                    // Specialized Templates Catalog Grid
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SPECIALIZED TEMPLATES")
                            .font(AppTheme.editorialFont(10, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .tracking(1.8)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(BookFormatMode.allCases) { format in
                                TemplateCard(format: format, isHovered: hoveredCard == format) {
                                    _ = launchStore.createNewBook(format: format)
                                }
                                .onHover { hovering in
                                    hoveredCard = hovering ? format : nil
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                        }
                    }
                    
                    // Writer's Block Sandbox Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("WRITER'S BLOCK SAFEGUARD")
                                .font(AppTheme.editorialFont(10, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .tracking(1.8)
                            
                            Spacer()
                            
                            // A beautiful small creative sanctuary tag badge
                            Text("CREATIVE SANCTUARY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(AppTheme.accentWorld)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(AppTheme.accentWorld.opacity(0.12), in: Capsule())
                        }
                        
                        Button {
                            launchStore.startScratchCanvas(parentBook: launchStore.currentBook)
                        } label: {
                            HStack(spacing: 20) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.accentWorld.opacity(0.16), AppTheme.accentWorld.opacity(0.04)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(AppTheme.accentWorld)
                                            .rotationEffect(.degrees(hoverSandbox ? 15 : 0))
                                            .scaleEffect(hoverSandbox ? 1.15 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoverSandbox)
                                    )
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Free-Drafting Scratch Canvas Sandbox")
                                        .font(AppTheme.editorialFont(16, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("Start typing immediately on a clean, separate sheet without modifying your manuscript files. Appends or merges successful paragraphs in a single click.")
                                        .font(AppTheme.uiFont(11.5))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineSpacing(3)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppTheme.accentWorld)
                                    .padding(10)
                                    .background(AppTheme.accentWorld.opacity(0.08), in: Circle())
                                    .offset(x: hoverSandbox ? 4 : 0)
                                    .scaleEffect(hoverSandbox ? 1.08 : 1.0)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hoverSandbox)
                            }
                            .padding(22)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        hoverSandbox
                                            ? LinearGradient(
                                                colors: [AppTheme.accentWorld.opacity(0.6), AppTheme.accentWorld.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                              )
                                            : LinearGradient(
                                                colors: [AppTheme.border, AppTheme.border.opacity(0.5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                              ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(
                                color: hoverSandbox ? AppTheme.accentWorld.opacity(0.18) : Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04),
                                radius: hoverSandbox ? 14 : 8, y: hoverSandbox ? 6 : 3
                            )
                            .scaleEffect(hoverSandbox ? 1.015 : 1.0)
                            .offset(y: hoverSandbox ? -2 : 0)
                            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: hoverSandbox)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoverSandbox = hovering
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                    
                    // Quick Action Buttons
                    HStack(spacing: 14) {
                        Button {
                            let panel = NSOpenPanel()
                            panel.title = "Open Bookworm File"
                            panel.allowedContentTypes = [.init(filenameExtension: "bookworm")!]
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                launchStore.loadBook(url: url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Open from Disk…")
                            }
                        }
                        .buttonStyle(SecondaryPillButtonStyle())
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        
                        Button {
                            _ = launchStore.createNewBook(format: .novel)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Start Blank Book")
                            }
                        }
                        .buttonStyle(SecondaryPillButtonStyle())
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                    .padding(.bottom, 48)
                }
                .padding(.horizontal, 48)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    AppTheme.background
                    
                    // Soft, whispered linen texture backing overlay
                    DotLinenOverlay()
                        .opacity(colorScheme == .dark ? 0.03 : 0.05)
                }
            )
        }
        .frame(minWidth: 950, minHeight: 650)
        .onAppear {
            recentBooks = RecentBooksStore.shared.recents
        }
    }
}

// MARK: - Template Card View Component

private struct TemplateCard: View {
    let format: BookFormatMode
    let isHovered: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    // Squircle Icon Container with gradient matching the workflow theme
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.16), accentColor.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: format.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accentColor)
                        )
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentColor)
                        .opacity(isHovered ? 1.0 : 0.0)
                        .scaleEffect(isHovered ? 1.0 : 0.8)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(format.rawValue)
                        .font(AppTheme.editorialFont(15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text(templateDescription)
                        .font(AppTheme.uiFont(11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(height: 34, alignment: .topLeading)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isHovered ? accentColor.opacity(0.4) : AppTheme.border, lineWidth: 1.2)
            )
            .shadow(
                color: isHovered ? accentColor.opacity(0.12) : Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04),
                radius: isHovered ? 12 : 6,
                y: isHovered ? 5 : 2
            )
            .scaleEffect(isHovered ? 1.025 : 1.0)
            .offset(y: isHovered ? -3 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
    }

    private var accentColor: Color {
        switch format {
        case .novel: return AppTheme.accentWrite
        case .email: return AppTheme.accentNarrate
        case .letter: return AppTheme.accentWorld
        case .essay: return AppTheme.success
        case .proposal: return AppTheme.accentPublish
        }
    }

    private var templateDescription: String {
        switch format {
        case .novel:
            return "Multi-chapter manuscripts, Character Vaults, and full Storyboard OutlineCorkboard panels."
        case .email:
            return "Collapses sidebar for single focus cards. Pre-populated draft styles and fast clipboard actions."
        case .letter:
            return "Vintage styling with spacious line heights, Georgia fonts, and wide formatting margins."
        case .essay:
            return "Double-spaced pages, standard margins, and centered circular word progression dials."
        case .proposal:
            return "Initializes five segmented structural scopes for executive summary, budgets, and milestones."
        }
    }
}

// MARK: - Recent Manuscript Row View

private struct RecentItemRow: View {
    let recent: RecentBook
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var hovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(recent.exists ? AppTheme.accentWrite.opacity(0.08) : Color.red.opacity(0.06))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: recent.exists ? "doc.plaintext.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(recent.exists ? AppTheme.accentWrite : Color.red)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(recent.title.isEmpty ? (recent.url?.deletingPathExtension().lastPathComponent ?? "Untitled") : recent.title)
                    .font(AppTheme.editorialFont(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                
                Text(recent.savedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTheme.editorialFont(9.5))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            Spacer()
            
            if hovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(width: 18, height: 18)
                        .background(Color.red.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovered ? AppTheme.surface : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(hovered ? AppTheme.border : Color.clear, lineWidth: 1)
        )
        .shadow(
            color: hovered ? Color.black.opacity(colorScheme == .dark ? 0.15 : 0.02) : Color.clear,
            radius: 4, y: 1
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if recent.exists { onSelect() }
        }
        .disabled(!recent.exists)
        .scaleEffect(hovered ? 1.01 : 1.0)
        .offset(y: hovered ? -0.5 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: hovered)
        .onHover { hovering in
            hovered = hovering
            if hovering && recent.exists { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Dot/Linen texture overlay for background

struct DotLinenOverlay: View {
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 1.2
            let spacing: CGFloat = 24
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(AppTheme.textSecondary.opacity(0.24))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .ignoresSafeArea()
    }
}
