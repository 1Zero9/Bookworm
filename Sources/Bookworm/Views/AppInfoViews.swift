import SwiftUI
import AppKit

struct AboutBookwormView: View {
    var body: some View {
        VStack(spacing: 18) {
            if let icon = AppTheme.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 116, height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: AppTheme.accentWrite.opacity(0.28), radius: 24, y: 10)
            }

            VStack(spacing: 6) {
                Text("Bookworm")
                    .font(AppTheme.editorialFont(32, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("A quiet novel writing desk.")
                    .font(AppTheme.uiFont(13))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            VStack(spacing: 4) {
                Text("Version \(AppTheme.version) (Build \(AppTheme.build))")
                    .font(AppTheme.uiFont(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Copyright © 2026 Stephen Cranfield. All rights reserved.")
                    .font(AppTheme.uiFont(11))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Divider().background(AppTheme.border)

            Text("Bookworm stores manuscripts locally as `.bookworm` files, creates timestamped backups before overwriting, and supports portable Markdown export.")
                .font(AppTheme.uiFont(12))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 360)
        }
        .padding(32)
        .frame(width: 460)
        .background(AppTheme.background)
    }
}

struct BookwormHelpView: View {
    @State private var selectedTab: Tab = .help

    enum Tab: String, CaseIterable, Identifiable {
        case help = "Help"
        case versionHistory = "Version History"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppTheme.border)

            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)

            Divider().background(AppTheme.border)

            switch selectedTab {
            case .help:
                helpContent
            case .versionHistory:
                versionHistory
            }
        }
        .frame(width: 720, height: 620)
        .background(AppTheme.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let icon = AppTheme.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Bookworm Help")
                    .font(AppTheme.editorialFont(20, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Version \(AppTheme.version) · Build \(AppTheme.build)")
                    .font(AppTheme.uiFont(11))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(18)
    }

    private var helpContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HelpSection(
                    title: "Writing",
                    items: [
                        "Use the chapter sidebar to move through your manuscript.",
                        "Use New Chapter to add structure as the book grows.",
                        "Use the reading-width toggle for a calmer drafting column.",
                        "Use Focus Mode when you want the interface out of the way."
                    ]
                )

                HelpSection(
                    title: "Saving and Portability",
                    items: [
                        "Save keeps your editable source as a `.bookworm` file.",
                        "Before an existing `.bookworm` file is overwritten, Bookworm creates a timestamped backup beside it.",
                        "Use Export Markdown to create a portable folder with one Markdown file per chapter."
                    ]
                )

                HelpSection(
                    title: "Planning and Revision",
                    items: [
                        "Use World Bible for characters, rules, places, and reference notes.",
                        "Use Storyboard for chapter-level organisation.",
                        "Use Red Pen for review notes and manuscript annotations."
                    ]
                )

                HelpSection(
                    title: "Files",
                    items: [
                        "Native files use the `.bookworm` extension.",
                        "Backups are stored in a `Bookworm Backups` folder beside the saved book.",
                        "PDF and Markdown exports are for sharing or portability, not the editable source of truth."
                    ]
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var versionHistory: some View {
        ScrollView {
            Text(Self.changelogText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .background(AppTheme.surface.opacity(0.35))
    }

    private static var changelogText: String {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md", subdirectory: "Resources"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "Version history is not available in this build."
        }
        return text
    }
}

private struct HelpSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTheme.editorialFont(16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(AppTheme.accentWrite)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(item)
                            .font(AppTheme.uiFont(12))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(3)
                    }
                }
            }
        }
    }
}
