import SwiftUI
import AppKit
import PDFKit

struct PublishView: View {
    @Environment(Book.self) private var book
    @State private var isExporting = false
    @State private var exported = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            if let icon = AppTheme.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .opacity(0.50)
            }

            // Title
            VStack(spacing: 8) {
                Text("PUBLISH")
                    .font(AppTheme.editorialFont(28, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Export your finished story as a PDF")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            // Book summary
            VStack(alignment: .leading, spacing: 6) {
                summaryRow(label: "Title",    value: book.title.isEmpty   ? "Untitled" : book.title)
                summaryRow(label: "Author",   value: book.author.isEmpty  ? "—" : book.author)
                summaryRow(label: "Chapters", value: "\(book.chapters.count)")
                summaryRow(label: "Words",    value: "\(totalWords) words")
            }
            .padding(16)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)

            // Export button
            Button {
                exportPDF()
            } label: {
                HStack(spacing: 10) {
                    if isExporting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: exported ? "checkmark.circle.fill" : "square.and.arrow.up")
                    }
                    Text(exported ? "Exported!" : "Export as PDF")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(AppTheme.accentPublish, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isExporting)

            Text("PDF opens in Preview — you can print, share, or save from there.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var totalWords: Int {
        book.chapters.reduce(0) { $0 + $1.rawText.split(separator: " ").count }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - PDF export

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.title = "Export as PDF"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (book.title.isEmpty ? "My Novel" : book.title)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let data = buildPDF()
            try? data.write(to: url)
            DispatchQueue.main.async {
                isExporting = false
                exported = true
                NSWorkspace.shared.open(url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { exported = false }
            }
        }
    }

    private func buildPDF() -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4
        let margin: CGFloat = 72

        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        var info: [AnyHashable: Any] = [
            kCGPDFContextTitle as String:  book.title,
            kCGPDFContextAuthor as String: book.author
        ]
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary) else { return Data() }

        func newPage() {
            ctx.beginPDFPage(nil as CFDictionary?)
        }
        func endPage() {
            ctx.endPDFPage()
        }
        func drawText(_ text: String, rect: CGRect, font: NSFont, color: NSColor = .textColor,
                      alignment: NSTextAlignment = .left) {
            let para = NSMutableParagraphStyle()
            para.alignment = alignment
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: para
            ]
            let nsText = NSAttributedString(string: text, attributes: attrs)
            // Flip coordinate system for text drawing
            ctx.saveGState()
            ctx.translateBy(x: 0, y: pageRect.height)
            ctx.scaleBy(x: 1, y: -1)
            let flippedRect = CGRect(x: rect.minX, y: pageRect.height - rect.maxY,
                                     width: rect.width, height: rect.height)
            nsText.draw(in: flippedRect)
            ctx.restoreGState()
        }

        let bodyFont = NSFont(name: "Georgia", size: 12) ?? NSFont.systemFont(ofSize: 12)
        let titleFont = AppTheme.editorialNSFont(28, weight: .bold)
        let chapterFont = AppTheme.editorialNSFont(20, weight: .bold)
        let contentRect = pageRect.insetBy(dx: margin, dy: margin)

        // --- Cover page ---
        newPage()
        let coverTitle = book.title.isEmpty ? "Untitled Novel" : book.title
        drawText(coverTitle,
                 rect: CGRect(x: margin, y: pageRect.midY - 30, width: pageRect.width - margin*2, height: 60),
                 font: titleFont, color: NSColor(hex: "#1C1B1A"), alignment: .center)
        if !book.author.isEmpty {
            drawText(book.author,
                     rect: CGRect(x: margin, y: pageRect.midY + 40, width: pageRect.width - margin*2, height: 30),
                     font: NSFont(name: "Georgia-Italic", size: 16) ?? bodyFont,
                     color: .secondaryLabelColor, alignment: .center)
        }
        endPage()

        // --- Chapters ---
        for chapter in book.chapters {
            // Chapter header page
            newPage()
            drawText(chapter.title,
                     rect: CGRect(x: margin, y: pageRect.midY - 20, width: pageRect.width - margin*2, height: 50),
                     font: chapterFont, color: NSColor(hex: "#1C1B1A"), alignment: .center)
            endPage()

            // Prose pages
            let paragraphs = chapter.rawText
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var y = contentRect.minY
            newPage()

            for para in paragraphs {
                let text = NSAttributedString(string: para + "\n",
                    attributes: [.font: bodyFont, .foregroundColor: NSColor.textColor])
                let framesetter = CTFramesetterCreateWithAttributedString(text)
                let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter, CFRange(location: 0, length: 0),
                    nil, CGSize(width: contentRect.width, height: CGFloat.greatestFiniteMagnitude), nil)

                if y + frameSize.height > contentRect.maxY {
                    endPage()
                    newPage()
                    y = contentRect.minY
                }

                let paraRect = CGRect(x: margin, y: y, width: contentRect.width, height: frameSize.height + 4)
                drawText(para, rect: paraRect, font: bodyFont)
                y += frameSize.height + 10
            }
            endPage()
        }

        ctx.closePDF()
        return data as Data
    }
}
