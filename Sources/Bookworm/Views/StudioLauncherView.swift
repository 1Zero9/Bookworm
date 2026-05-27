import SwiftUI
import AppKit

struct StudioLauncherView: View {
    @ObservedObject var launchStore: LaunchStore = .shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var recentBooks: [RecentBook] = []

    var body: some View {
        HStack(spacing: 0) {
            recentSidebar

            Divider().background(AppTheme.border.opacity(0.6))

            startPanel
        }
        .frame(minWidth: 950, minHeight: 650)
        .onAppear {
            recentBooks = RecentBooksStore.shared.recents
        }
    }

    private var recentSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            ScrollView {
                VStack(spacing: 8) {
                    if recentBooks.isEmpty {
                        emptyRecentState
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
        .background(
            LinearGradient(
                colors: [
                    AppTheme.sidebar,
                    Color(NSColor.dynamic(
                        light: NSColor(hex: "#EEF3FA"),
                        dark: NSColor(hex: "#0D1422")
                    ))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var emptyRecentState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentWrite.opacity(0.06))
                    .frame(width: 64, height: 64)
                    .blur(radius: 8)

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
                Text("No Recent Books")
                    .font(AppTheme.editorialFont(13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Books you open will appear here.")
                    .font(AppTheme.uiFont(10.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .lineSpacing(2)
            }
        }
        .padding(.top, 48)
        .frame(maxWidth: .infinity)
    }

    private var startPanel: some View {
        ZStack {
            LauncherAtmosphereBackground()

            if let icon = AppTheme.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 520, height: 520)
                    .opacity(colorScheme == .dark ? 0.20 : 0.16)
                    .blur(radius: 2)
                    .rotationEffect(.degrees(-5))
                    .offset(x: 360, y: -190)
                    .allowsHitTesting(false)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    HStack(alignment: .center, spacing: 30) {
                        if let icon = AppTheme.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 142, height: 142)
                                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                                        .stroke(.white.opacity(colorScheme == .dark ? 0.20 : 0.55), lineWidth: 1)
                                )
                                .shadow(color: Color(hex: "#087CFF").opacity(colorScheme == .dark ? 0.55 : 0.28), radius: 42, x: -12, y: 18)
                                .shadow(color: Color(hex: "#7C4DFF").opacity(colorScheme == .dark ? 0.42 : 0.24), radius: 46, x: 18, y: 12)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("NOVEL WORKSPACE")
                                .font(AppTheme.uiFont(10, weight: .bold))
                                .tracking(2.4)
                                .foregroundStyle(AppTheme.accentWrite)

                            Text("Bookworm")
                                .font(AppTheme.editorialFont(64, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Open the book. Find the thread. Keep writing.")
                                .font(AppTheme.uiFont(17, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(4)
                                .frame(maxWidth: 560, alignment: .leading)
                        }
                    }
                    .padding(.top, 68)

                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Continue Writing")
                                .font(AppTheme.editorialFont(22, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Spacer()

                            Text(recentBooks.isEmpty ? "No recent manuscript" : "\(recentBooks.count) recent")
                                .font(AppTheme.uiFont(11, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        HStack(spacing: 14) {
                            LauncherActionCard(
                                title: "New Novel",
                                subtitle: "Begin with a blank novel manuscript.",
                                icon: "plus",
                                filledIcon: true
                            ) {
                                _ = launchStore.createNewBook(format: .novel)
                            }

                            LauncherActionCard(
                                title: "Open Book",
                                subtitle: "Choose a Bookworm file from disk.",
                                icon: "folder",
                                filledIcon: false
                            ) {
                                openBook()
                            }
                        }
                    }
                    .padding(30)
                    .frame(maxWidth: 720, alignment: .leading)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AppTheme.surface.opacity(colorScheme == .dark ? 0.72 : 0.82))
                                .shadow(color: Color(hex: "#08111F").opacity(colorScheme == .dark ? 0.36 : 0.10), radius: 34, y: 18)
                                .shadow(color: Color(hex: "#087CFF").opacity(colorScheme == .dark ? 0.14 : 0.08), radius: 42, x: -12, y: 8)

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.30),
                                            Color(hex: "#7C8CFF").opacity(colorScheme == .dark ? 0.05 : 0.08),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.border.opacity(0.7), lineWidth: 1)

                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#087CFF"), Color(hex: "#7C4DFF"), Color(hex: "#FF7A3D")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 3)
                                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }

                    if !recentBooks.isEmpty {
                        recentSummary
                            .padding(.top, 2)
                    }

                    Spacer(minLength: 48)
                }
                .padding(.horizontal, 72)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recentSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Books")
                .font(AppTheme.editorialFont(12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(recentBooks.prefix(3)) { recent in
                Button {
                    if let url = recent.url {
                        launchStore.loadBook(url: url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: recent.exists ? "doc.plaintext" : "exclamationmark.triangle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(recent.exists ? AppTheme.accentWrite : Color.red)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(recent.title.isEmpty ? (recent.url?.deletingPathExtension().lastPathComponent ?? "Untitled") : recent.title)
                                .font(AppTheme.editorialFont(12, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)

                            Text(recent.savedDate.formatted(date: .abbreviated, time: .shortened))
                                .font(AppTheme.editorialFont(9.5))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: 460, alignment: .leading)
                    .background(AppTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border.opacity(0.8), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!recent.exists)
                .onHover { hovering in
                    if hovering && recent.exists { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
    }

    private func openBook() {
        let panel = NSOpenPanel()
        panel.title = "Open Bookworm File"
        panel.allowedContentTypes = [.init(filenameExtension: "bookworm")!]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            launchStore.loadBook(url: url)
        }
    }
}

private struct LauncherAtmosphereBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "#050914"), Color(hex: "#0A1630"), Color(hex: "#1C1236")]
                    : [Color(hex: "#E8F2FF"), Color(hex: "#F4F0FF"), Color(hex: "#FFF4E8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(hex: "#087CFF").opacity(colorScheme == .dark ? 0.46 : 0.30), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 520
            )
            .offset(x: -160, y: -160)

            RadialGradient(
                colors: [Color(hex: "#7C4DFF").opacity(colorScheme == .dark ? 0.42 : 0.24), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 620
            )
            .offset(x: 180, y: 160)

            RadialGradient(
                colors: [Color(hex: "#FF7A3D").opacity(colorScheme == .dark ? 0.22 : 0.20), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 430
            )
            .offset(x: 170, y: -70)

            RoundedRectangle(cornerRadius: 72, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.035 : 0.30),
                            Color(hex: "#087CFF").opacity(colorScheme == .dark ? 0.10 : 0.08),
                            Color(hex: "#7C4DFF").opacity(colorScheme == .dark ? 0.12 : 0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 72, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25), lineWidth: 1)
                )
                .frame(width: 560, height: 390)
                .rotationEffect(.degrees(-8))
                .offset(x: 270, y: -210)
                .blur(radius: 0.5)

            DotLinenOverlay()
                .opacity(colorScheme == .dark ? 0.055 : 0.075)

            LinearGradient(
                colors: [.black.opacity(colorScheme == .dark ? 0.34 : 0.07), .clear, .black.opacity(colorScheme == .dark ? 0.24 : 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct LauncherActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let filledIcon: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(filledIcon ? AppTheme.surface : AppTheme.accentWrite)
                    .frame(width: 36, height: 36)
                    .background(
                        filledIcon ? AppTheme.accentWrite : AppTheme.accentWrite.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.editorialFont(17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(AppTheme.uiFont(11.5))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(width: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(hovered ? AppTheme.accentWrite.opacity(0.35) : AppTheme.border, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04),
                radius: hovered ? 10 : 8,
                y: hovered ? 4 : 3
            )
            .offset(y: hovered ? -1 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
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
