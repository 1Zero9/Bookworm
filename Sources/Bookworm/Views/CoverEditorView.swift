import SwiftUI
import AppKit

struct CoverEditorView: View {
    @Environment(Book.self) private var book
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let cover = book.coverImage {
                Image(nsImage: cover.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 16) {
                    if let icon = AppTheme.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 110, height: 110)
                            .opacity(0.25)
                    } else {
                        Image(systemName: "book.closed.circle")
                            .font(.system(size: 80))
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.3))
                    }

                    Text("Set Your Cover")
                        .font(AppTheme.editorialFont(20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Choose a cover image file from your Mac.")
                        .font(AppTheme.editorialFont(13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 36)
                .frame(maxWidth: 440)
                .editorialCard(cornerRadius: 16)
                .padding(.bottom, 10)
            }

            Button {
                pickImage()
            } label: {
                Text(book.coverImage == nil ? "Choose File..." : "Change Cover...")
                    .help("Select a custom cover image file from your Mac")
            }
            .buttonStyle(SecondaryPillButtonStyle())

            Spacer()

            Text("Tip: you can also drag and drop cover files directly onto your Book Preview pane.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let img = NSImage(contentsOf: url) else { return }
        book.coverImage = BookImage(nsImage: img, placement: .cover)
    }
}
