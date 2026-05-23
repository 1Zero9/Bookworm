import SwiftUI
import AppKit
import PDFKit

struct PublishView: View {
    @Environment(Book.self) private var book
    @State private var isExporting = false
    @State private var exported = false
    @State private var includeGallery = true
    @State private var includeChapterArt = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)

                if let icon = AppTheme.appIcon {
                    Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80).opacity(0.50)
                }

                VStack(spacing: 6) {
                    Text("PUBLISH")
                        .font(AppTheme.editorialFont(24, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Export your finished story as a PDF")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }

                // Book summary
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow(label: "Title",    value: book.title.isEmpty ? "Untitled" : book.title)
                    summaryRow(label: "Author",   value: book.author.isEmpty ? "—" : book.author)
                    summaryRow(label: "Chapters", value: "\(book.chapters.count)")
                    summaryRow(label: "Words",    value: "\(totalWords) words")
                }
                .padding(16)
                .editorialCard(cornerRadius: 12)
                .padding(.horizontal, 32)

                // Export options
                let imgCount = book.worldCharacters.filter { $0.hasImage }.count
                VStack(alignment: .leading, spacing: 14) {
                    Text("OPTIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.accentPublish)
                        .tracking(0.8)

                    Toggle(isOn: $includeGallery) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Character & Things Gallery")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("\(imgCount) portrait\(imgCount == 1 ? "" : "s") — a cast page before the story begins")
                                .font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .tint(AppTheme.accentPublish)
                    .disabled(imgCount == 0).opacity(imgCount == 0 ? 0.4 : 1)

                    Toggle(isOn: $includeChapterArt) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chapter Portraits")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Shows portraits of characters appearing in each chapter")
                                .font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .tint(AppTheme.accentPublish)
                    .disabled(imgCount == 0).opacity(imgCount == 0 ? 0.4 : 1)
                }
                .padding(16)
                .editorialCard(cornerRadius: 12)
                .padding(.horizontal, 32)

                Button { exportPDF() } label: {
                    HStack(spacing: 10) {
                        if isExporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: exported ? "checkmark.circle.fill" : "square.and.arrow.up")
                        }
                        Text(exported ? "Exported!" : "Export as PDF")
                    }
                    .help("Compile and save your entire book manuscript as a beautifully formatted PDF document")
                }
                .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentPublish, fontSize: 13))
                .disabled(isExporting)
                .padding(.horizontal, 32)

                Text("PDF opens in Preview — you can print, share, or save from there.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)

                Spacer()
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var totalWords: Int {
        book.chapters.reduce(0) { $0 + $1.rawText.split(separator: " ").count }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                .frame(width: 70, alignment: .leading)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
        }
    }

    // MARK: - Export

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.title = "Export as PDF"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = book.title.isEmpty ? "My Novel" : book.title
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isExporting = true
        let doGallery = includeGallery
        let doChapterArt = includeChapterArt
        DispatchQueue.global(qos: .userInitiated).async {
            let data = buildPDF(gallery: doGallery, chapterArt: doChapterArt)
            try? data.write(to: url)
            DispatchQueue.main.async {
                isExporting = false; exported = true
                NSWorkspace.shared.open(url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { exported = false }
            }
        }
    }

    // MARK: - PDF builder

    private func buildPDF(gallery: Bool, chapterArt: Bool) -> Data {
        let pageW: CGFloat = 595, pageH: CGFloat = 842
        let pageRect = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let margin: CGFloat = 72
        let contentW = pageW - margin * 2

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, [
            kCGPDFContextTitle as String: book.title,
            kCGPDFContextAuthor as String: book.author
        ] as CFDictionary) else { return Data() }

        let bodyFont    = NSFont(name: "Georgia", size: 12) ?? NSFont.systemFont(ofSize: 12)
        let titleFont   = AppTheme.editorialNSFont(28, weight: .bold)
        let chapterFont = AppTheme.editorialNSFont(20, weight: .bold)
        let labelFont   = NSFont(name: "Georgia", size: 9) ?? NSFont.systemFont(ofSize: 9)
        let captionFont = NSFont.systemFont(ofSize: 7.5)

        // Draw text using CoreText — works on any thread (no NSGraphicsContext required).
        // rect is in PDF native coords (y=0 at bottom). CTFrameDraw renders top-to-bottom within the frame.
        func drawText(_ text: String, in rect: CGRect, font: NSFont,
                      color: NSColor = .textColor, align: NSTextAlignment = .left) {
            guard !text.isEmpty else { return }
            let para = NSMutableParagraphStyle(); para.alignment = align
            let attrStr = NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: para
            ])
            let setter = CTFramesetterCreateWithAttributedString(attrStr)
            let path = CGMutablePath(); path.addRect(rect)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
        }

        // Draw image clipped to circle or rounded rect, scale-to-fill.
        func drawImage(_ nsImage: NSImage, in rect: CGRect, circular: Bool) {
            guard let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            ctx.saveGState()
            if circular {
                ctx.addEllipse(in: rect)
            } else {
                let r = min(rect.width, rect.height) * 0.1
                let path = CGMutablePath()
                path.addRoundedRect(in: rect, cornerWidth: r, cornerHeight: r)
                ctx.addPath(path)
            }
            ctx.clip()
            let imgAspect = CGFloat(cg.width) / CGFloat(cg.height)
            let rectAspect = rect.width / rect.height
            let fill: CGRect
            if imgAspect > rectAspect {
                let w = rect.height * imgAspect
                fill = CGRect(x: rect.midX - w/2, y: rect.minY, width: w, height: rect.height)
            } else {
                let h = rect.width / imgAspect
                fill = CGRect(x: rect.minX, y: rect.midY - h/2, width: rect.width, height: h)
            }
            ctx.draw(cg, in: fill)
            ctx.restoreGState()
        }

        // Render a gallery page (or pages) for a set of characters/things.
        func renderGallery(items: [WorldCharacter], heading: String, cols: Int, imgSize: CGFloat) {
            guard !items.isEmpty else { return }
            let cellW   = contentW / CGFloat(cols)
            let cellH   = imgSize + 32          // portrait + name + caption
            let headH: CGFloat = 40
            let rowsPerPage = max(1, Int((pageH - 2*margin - headH) / cellH))
            let perPage = cols * rowsPerPage

            var idx = 0
            var pageNum = 0
            while idx < items.count {
                ctx.beginPDFPage(nil as CFDictionary?)
                let slice = Array(items[idx..<min(idx + perPage, items.count)])
                idx += perPage; pageNum += 1

                if pageNum == 1 {
                    drawText(heading,
                             in: CGRect(x: margin, y: pageH - margin - headH + 10, width: contentW, height: 22),
                             font: NSFont(name: "Georgia", size: 12) ?? bodyFont,
                             color: NSColor(hex: "#999999"), align: .center)
                }
                let gridTop = pageNum == 1 ? pageH - margin - headH : pageH - margin - 16

                for (i, char) in slice.enumerated() {
                    let col = i % cols
                    let row = i / cols
                    let cx  = margin + CGFloat(col) * cellW
                    let ix  = cx + (cellW - imgSize) / 2
                    let iy  = gridTop - CGFloat(row) * cellH - imgSize

                    drawImage(char.resolvedImage,
                              in: CGRect(x: ix, y: iy, width: imgSize, height: imgSize),
                              circular: char.kind == .character)

                    drawText(char.name,
                             in: CGRect(x: cx, y: iy - 20, width: cellW, height: 18),
                             font: labelFont, color: NSColor(hex: "#333333"), align: .center)

                    let bio = char.biography.isEmpty ? char.physicalDescription : char.biography
                    if !bio.isEmpty {
                        let snip = String(bio.prefix(58)).trimmingCharacters(in: .whitespaces)
                        drawText(snip + (bio.count > 58 ? "…" : ""),
                                 in: CGRect(x: cx + 4, y: iy - 30, width: cellW - 8, height: 10),
                                 font: captionFont, color: NSColor(hex: "#AAAAAA"), align: .center)
                    }
                }
                ctx.endPDFPage()
            }
        }

        // MARK: Cover page
        ctx.beginPDFPage(nil as CFDictionary?)
        let coverTitle = book.title.isEmpty ? "Untitled" : book.title
        drawText(coverTitle,
                 in: CGRect(x: margin, y: pageH/2, width: contentW, height: 56),
                 font: titleFont, color: NSColor(hex: "#1C1B1A"), align: .center)
        if !book.author.isEmpty {
            drawText(book.author,
                     in: CGRect(x: margin, y: pageH/2 - 44, width: contentW, height: 30),
                     font: NSFont(name: "Georgia-Italic", size: 16) ?? bodyFont,
                     color: .secondaryLabelColor, align: .center)
        }
        ctx.endPDFPage()

        // MARK: Gallery
        if gallery {
            renderGallery(
                items: book.worldCharacters.filter { $0.kind == .character && $0.hasImage },
                heading: "CHARACTERS",
                cols: 3, imgSize: 90
            )
            renderGallery(
                items: book.worldCharacters.filter { $0.kind == .thing && $0.hasImage },
                heading: "PLACES & THINGS",
                cols: 2, imgSize: 110
            )
        }

        // MARK: Chapters
        let contentRect = pageRect.insetBy(dx: margin, dy: margin)

        for chapter in book.chapters {
            // Chapter heading page
            ctx.beginPDFPage(nil as CFDictionary?)
            drawText(chapter.title,
                     in: CGRect(x: margin, y: pageH/2 + 10, width: contentW, height: 48),
                     font: chapterFont, color: NSColor(hex: "#1C1B1A"), align: .center)

            if chapterArt {
                let mentioned = book.worldCharacters.filter { char in
                    let key = (char.name.components(separatedBy: " ").first ?? char.name)
                    return key.count >= 3 && chapter.rawText.localizedCaseInsensitiveContains(key)
                }.filter { $0.hasImage }

                if !mentioned.isEmpty {
                    let portraits = Array(mentioned.prefix(4))
                    let imgSize: CGFloat = 52
                    let gap: CGFloat = 16
                    let totalW = CGFloat(portraits.count) * imgSize + CGFloat(portraits.count - 1) * gap
                    var x = (pageW - totalW) / 2
                    let iy = pageH/2 - 80  // below the chapter title

                    for char in portraits {
                        drawImage(char.resolvedImage,
                                  in: CGRect(x: x, y: iy, width: imgSize, height: imgSize),
                                  circular: char.kind == .character)
                        let first = char.name.components(separatedBy: " ").first ?? char.name
                        drawText(first,
                                 in: CGRect(x: x - 4, y: iy - 14, width: imgSize + 8, height: 12),
                                 font: captionFont, color: NSColor(hex: "#888888"), align: .center)
                        x += imgSize + gap
                    }
                }
            }
            ctx.endPDFPage()

            // Prose pages
            let paragraphs = chapter.rawText
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // paragraphTop tracks the PDF-coord top edge of the next paragraph.
            // PDF y increases upward, so we start near the top and subtract each paragraph's height.
            var paragraphTop = contentRect.maxY
            ctx.beginPDFPage(nil as CFDictionary?)

            for para in paragraphs {
                let attrText = NSAttributedString(string: para + "\n",
                    attributes: [.font: bodyFont, .foregroundColor: NSColor.black])
                let setter = CTFramesetterCreateWithAttributedString(attrText)
                let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(
                    setter, CFRange(location: 0, length: 0), nil,
                    CGSize(width: contentRect.width, height: .greatestFiniteMagnitude), nil)

                let paraH = frameSize.height + 4
                if paragraphTop - paraH < contentRect.minY {
                    ctx.endPDFPage()
                    ctx.beginPDFPage(nil as CFDictionary?)
                    paragraphTop = contentRect.maxY
                }

                drawText(para,
                         in: CGRect(x: margin, y: paragraphTop - paraH, width: contentRect.width, height: paraH),
                         font: bodyFont)
                paragraphTop -= paraH + 10
            }
            ctx.endPDFPage()
        }

        ctx.closePDF()
        return data as Data
    }
}
