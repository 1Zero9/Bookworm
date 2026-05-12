import SwiftUI
import AppKit

struct CoverEditorView: View {
    @Environment(Book.self) private var book

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if let cover = book.coverImage {
                Image(nsImage: cover.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 8)

                Button("Replace Cover Image") { pickImage() }
            } else {
                if let icon = AppTheme.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160, height: 160)
                        .opacity(0.45)
                }

                Text("No cover art yet")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.secondary)

                Button("Choose Cover Image…") { pickImage() }
                    .buttonStyle(.borderedProminent)
            }

            Spacer()

            Text("Tip: you can also drag and drop an image onto the cover page in Book Preview.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let img = NSImage(contentsOf: url) else { return }
        book.coverImage = BookImage(nsImage: img, placement: .cover)
    }
}
