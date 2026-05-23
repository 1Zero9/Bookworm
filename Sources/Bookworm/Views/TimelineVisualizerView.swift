import SwiftUI
import Observation

struct TimelineVisualizerView: View {
    @Environment(Book.self) private var book
    @State private var isAnalyzing = false
    @State private var showingAddSubplot = false
    @State private var editingSubplot: Subplot? = nil
    @State private var statusMessage: String? = nil

    var body: some View {
        @Bindable var book = book
        VStack(spacing: 0) {
            // Timeline Toolbar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plot Timeline")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Visualize subplots, arcs, and character trajectories across chapters")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(statusMessage ?? "Gemini extracting plot beats…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.accentNarrate)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(AppTheme.accentNarrate.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Button {
                        autoMapTimeline()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("AI Auto-Map Beats")
                        }
                        .help("Let Gemini read your chapters and automatically extract subplot beats")
                    }
                    .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentNarrate, fontSize: 11))

                    Button {
                        showingAddSubplot = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Add Subplot")
                        }
                        .help("Add a new subplot swimlane to trace story arcs")
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.surface)

            Divider().background(AppTheme.border)

            if book.chapters.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("No Chapters Found")
                        .font(.system(size: 14, weight: .bold))
                    Text("Add a chapter in the writer panel to start building your narrative timeline.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 16) {
                        // Header Row (Chapters)
                        GridRow {
                            // Top Left spacer above subplots
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SUBPLOTS")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .tracking(1.5)
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding(.bottom, 8)

                            ForEach(book.chapters.sorted(by: { $0.order < $1.order })) { chapter in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("CHAPTER \(chapter.order + 1)")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(AppTheme.accentWrite)
                                        .tracking(1.0)
                                    Text(chapter.title)
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                .frame(width: 220, alignment: .leading)
                                .padding(.bottom, 8)
                            }
                        }

                        // Tension & Pacing Heatmap Row
                        GridRow {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TENSION & PACING")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .tracking(1.5)
                                Text("Visualize and sculpt emotional tension and story arcs.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(3)
                                
                                Button {
                                    scanTensionWithAI()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                        Text("Scan Pacing")
                                    }
                                }
                                .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentNarrate, fontSize: 10))
                                .disabled(isAnalyzing)
                            }
                            .padding(12)
                            .frame(width: 180, alignment: .leading)
                            .editorialCard(cornerRadius: 10)

                            PacingVisualizerView(chapters: book.chapters.sorted(by: { $0.order < $1.order }))
                                .frame(height: 130)
                                .gridCellColumns(book.chapters.count)
                        }

                        // Subplot Rows
                        ForEach(book.subplots.sorted(by: { $0.order < $1.order })) { subplot in
                            GridRow {
                                // Subplot descriptor card
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hex: subplot.colorHex))
                                            .frame(width: 10, height: 10)
                                        Text(subplot.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 4) {
                                        Button {
                                            editingSubplot = subplot
                                        } label: {
                                            Text("Edit")
                                                .help("Edit subplot name and theme color")
                                        }
                                        .buttonStyle(GhostToolButtonStyle(tint: AppTheme.textSecondary))

                                        if book.subplots.count > 1 {
                                            Button {
                                                book.subplots.removeAll { $0.id == subplot.id }
                                                book.plotBeats.removeAll { $0.subplotID == subplot.id }
                                            } label: {
                                                Text("Delete")
                                                    .help("Permanently delete this subplot swimlane and all associated beats")
                                            }
                                            .buttonStyle(GhostToolButtonStyle(tint: .red.opacity(0.8)))
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(width: 180, alignment: .leading)
                                .editorialCard(cornerRadius: 10)

                                // Cells mapped to Chapters
                                ForEach(book.chapters.sorted(by: { $0.order < $1.order })) { chapter in
                                    TimelineCell(book: book, subplot: subplot, chapter: chapter)
                                        .frame(width: 220, height: 110)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .background(AppTheme.background)
            }
        }
        .sheet(isPresented: $showingAddSubplot) {
            var tempSubplot: Subplot? = nil
            SubplotEditorPopover(subplot: .init(get: { tempSubplot }, set: { tempSubplot = $0 }), book: book, isPresented: $showingAddSubplot)
        }
        .sheet(item: $editingSubplot) { subplot in
            SubplotEditorPopover(subplot: .init(get: { subplot }, set: { editingSubplot = $0 }), book: book, isPresented: .init(get: { editingSubplot != nil }, set: { if !$0 { editingSubplot = nil } }))
        }
    }

    private func autoMapTimeline() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        statusMessage = "Analyzing chapters…"

        Task {
            do {
                let charactersInfo = book.worldCharacters.map { "- \($0.name) (ID: \($0.id))" }.joined(separator: "\n")
                let subplotsInfo = book.subplots.map { "- \($0.name) (ID: \($0.id))" }.joined(separator: "\n")
                let chaptersInfo = book.chapters.sorted(by: { $0.order < $1.order }).map { ch in
                    let rawLimit = String(ch.rawText.prefix(2500))
                    return "Chapter ID: \(ch.id)\nTitle: \(ch.title)\nProse Sample:\n\(rawLimit)\n---"
                }.joined(separator: "\n\n")

                let prompt = """
                You are a premium storyboard director. Your task is to analyze the provided novel draft and extract the major plot events (beats) mapped chronologically to subplots.

                LEDGER INFORMATION:
                - Genre: \(book.coreLedger.genre)
                - Tone: \(book.coreLedger.tone)

                ACTORS IN WORLD BIBLE:
                \(charactersInfo.isEmpty ? "None listed" : charactersInfo)

                ACTIVE SUBPLOTS:
                \(subplotsInfo)

                NOVEL CHAPTERS:
                \(chaptersInfo)

                TASK:
                Identify key dramatic plot events (beats) occurring in each chapter. Map each beat to one of the active Subplots (matching by the Subplot UUIDs above) and specify which characters (matching by Character UUIDs above) are involved. 

                Return your storyboard mapping STRICTLY as a raw JSON array matching this exact schema:
                [
                  {
                    "chapterID": "UUID",
                    "subplotID": "UUID",
                    "beatTitle": "Catchy Title",
                    "beatSummary": "1-2 sentence dramatic summary",
                    "characterIDs": ["UUID"]
                  }
                ]
                """

                statusMessage = "Calling Gemini API…"
                let responseText = try await GeminiClient.shared.generate(prompt: prompt)

                statusMessage = "Ingesting plot beats…"
                let cleanResponse = GeminiClient.cleanJsonString(responseText)
                guard let data = cleanResponse.data(using: .utf8) else {
                    throw GeminiError.decodingFailed("Could not encode string to UTF-8")
                }

                struct AIPlotBeat: Decodable {
                    let chapterID: String
                    let subplotID: String
                    let beatTitle: String
                    let beatSummary: String
                    let characterIDs: [String]
                }

                let aiBeats = try JSONDecoder().decode([AIPlotBeat].self, from: data)

                await MainActor.run {
                    for beat in aiBeats {
                        guard let cID = UUID(uuidString: beat.chapterID),
                              let sID = UUID(uuidString: beat.subplotID) else { continue }

                        // Overwrite or append beat
                        if let existing = book.plotBeats.first(where: { $0.chapterID == cID && $0.subplotID == sID }) {
                            existing.title = beat.beatTitle
                            existing.summary = beat.beatSummary
                            existing.characterIDs = beat.characterIDs.compactMap { UUID(uuidString: $0) }
                        } else {
                            let newBeat = PlotBeat(
                                title: beat.beatTitle,
                                summary: beat.beatSummary,
                                subplotID: sID,
                                chapterID: cID,
                                characterIDs: beat.characterIDs.compactMap { UUID(uuidString: $0) }
                            )
                            book.plotBeats.append(newBeat)
                        }
                    }
                    isAnalyzing = false
                    statusMessage = nil
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    statusMessage = nil
                    // Show a soft toast or alert in production
                    let alert = NSAlert()
                    alert.messageText = "AI Extraction Failed"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }

    private func scanTensionWithAI() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        statusMessage = "Analyzing pacing & tension…"

        Task {
            do {
                let chaptersInfo = book.chapters.sorted(by: { $0.order < $1.order }).map { ch in
                    let rawLimit = String(ch.rawText.prefix(2000))
                    return "Chapter ID: \(ch.id)\nTitle: \(ch.title)\nProse Sample:\n\(rawLimit)\n---"
                }.joined(separator: "\n\n")

                let prompt = """
                You are a professional storyboard editor and dramatic structure analyst. Analyze the pacing and tension of the following novel chapters.
                
                Evaluate each chapter's narrative intensity on a scale of 1.0 (very low tension, e.g., calm exposition, breathing room, quiet transition) to 10.0 (maximum tension, e.g., ultimate climax, extreme conflict, high-stakes reveal).
                
                Provide a brief, compelling 1-sentence pacing summary justifying the tension score for each chapter.
                
                NOVEL CHAPTERS:
                \(chaptersInfo)
                
                TASK:
                Generate a pacing tension evaluation for each chapter. Return your evaluation strictly as a raw JSON array matching this schema:
                [
                  {
                    "chapterID": "UUID",
                    "tensionScore": 8.5,
                    "pacingSummary": "A sudden confrontation that shatters the brief peace and spikes emotional tension."
                  }
                ]
                """

                statusMessage = "Evaluating story arcs…"
                let responseText = try await GeminiClient.shared.generate(prompt: prompt)

                statusMessage = "Mapping pacing…"
                let cleanResponse = GeminiClient.cleanJsonString(responseText)
                guard let data = cleanResponse.data(using: .utf8) else {
                    throw GeminiError.decodingFailed("Could not encode string to UTF-8")
                }

                struct AIPacingItem: Decodable {
                    let chapterID: String
                    let tensionScore: Double
                    let pacingSummary: String
                }

                let pacingItems = try JSONDecoder().decode([AIPacingItem].self, from: data)

                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        for item in pacingItems {
                            guard let cID = UUID(uuidString: item.chapterID),
                                  let ch = book.chapters.first(where: { $0.id == cID }) else { continue }
                            ch.tensionScore = max(1.0, min(10.0, item.tensionScore))
                            ch.pacingSummary = item.pacingSummary
                        }
                    }
                    isAnalyzing = false
                    statusMessage = nil
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    statusMessage = nil
                    let alert = NSAlert()
                    alert.messageText = "AI Tension Scan Failed"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }
}

// MARK: - Subplot Editor Sheet

struct SubplotEditorPopover: View {
    @Binding var subplot: Subplot?
    let book: Book
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var colorHex: String = "#3DBFB8"

    let colors = ["#7C8CFF", "#3DBFB8", "#C9963A", "#9B72D0", "#EF4444", "#EC4899", "#F59E0B"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(subplot == nil ? "New Subplot Swimlane" : "Edit Subplot Settings")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Subplot Name").font(.system(size: 10, weight: .bold)).foregroundStyle(AppTheme.textSecondary)
                TextField("E.g., B-Plot: Romantic Tension", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Color").font(.system(size: 10, weight: .bold)).foregroundStyle(AppTheme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { color in
                        let isSelected = colorHex.uppercased() == color.uppercased()
                        ColorSelectionCircle(color: Color(hex: color), isSelected: isSelected) {
                            colorHex = color
                        }
                    }
                }
            }

            Spacer().frame(height: 8)

            HStack {
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .help("Discard changes")
                }
                .buttonStyle(SecondaryPillButtonStyle())

                Spacer()

                Button {
                    saveSubplot()
                    isPresented = false
                } label: {
                    Text("Save Swimlane")
                        .help("Save subplot configurations")
                }
                .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentWrite, fontSize: 11))
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear {
            if let subplot = subplot {
                name = subplot.name
                colorHex = subplot.colorHex
            }
        }
    }

    private func saveSubplot() {
        if let subplot = subplot {
            subplot.name = name.isEmpty ? "Untitled Subplot" : name
            subplot.colorHex = colorHex
        } else {
            let newSub = Subplot(name: name.isEmpty ? "New Subplot" : name, colorHex: colorHex, order: book.subplots.count)
            book.subplots.append(newSub)
        }
    }
}

// MARK: - Timeline Cell Widget

struct TimelineCell: View {
    let book: Book
    let subplot: Subplot
    let chapter: Chapter
    @State private var hovered = false
    @State private var showEditor = false

    var beat: PlotBeat? {
        book.plotBeats.first { $0.subplotID == subplot.id && $0.chapterID == chapter.id }
    }

    var body: some View {
        Group {
            if let beat = beat {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(beat.title.isEmpty ? "Untitled Beat" : beat.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            book.plotBeats.removeAll { $0.id == beat.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundStyle(.red.opacity(hovered ? 0.7 : 0.0))
                                .help("Delete this plot beat")
                        }
                        .buttonStyle(.plain)
                    }

                    Text(beat.summary.isEmpty ? "No summary added." : beat.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    // Characters Bubble Array
                    if !beat.characterIDs.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(beat.characterIDs.prefix(4), id: \.self) { charID in
                                if let char = book.worldCharacters.first(where: { $0.id == charID }) {
                                    Text(char.name.prefix(2).uppercased())
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(4)
                                        .background(Color(hex: subplot.colorHex).opacity(0.12))
                                        .foregroundStyle(Color(hex: subplot.colorHex))
                                        .clipShape(Circle())
                                        .help(char.name)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(AppTheme.surface)
                .overlay(
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(hex: subplot.colorHex))
                            .frame(width: 4)
                        Spacer()
                    }
                )
                .editorialCard(cornerRadius: 8)
                .glowingBorder(color: Color(hex: subplot.colorHex).opacity(0.35), active: hovered, radius: 4)
                .onTapGesture {
                    showEditor = true
                }
            } else {
                Button {
                    let newBeat = PlotBeat(title: "New Beat", summary: "", subplotID: subplot.id, chapterID: chapter.id)
                    book.plotBeats.append(newBeat)
                    showEditor = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("Add Beat")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(hovered ? Color(hex: subplot.colorHex) : AppTheme.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(hovered ? Color(hex: subplot.colorHex).opacity(0.04) : Color.clear)
                    .contentShape(Rectangle())
                    .help("Add a new storyline event beat for this chapter and subplot")
                }
                .buttonStyle(.plain)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hovered ? Color(hex: subplot.colorHex).opacity(0.3) : AppTheme.border.opacity(0.4), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 4]))
                )
            }
        }
        .onHover { hovered = $0 }
        .scaleEffect(hovered ? 1.015 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: hovered)
        .sheet(isPresented: $showEditor) {
            BeatEditorSheet(book: book, subplot: subplot, chapter: chapter, beat: beat, isPresented: $showEditor)
        }
    }
}

// MARK: - Beat Editor Sheet

struct BeatEditorSheet: View {
    let book: Book
    let subplot: Subplot
    let chapter: Chapter
    let beat: PlotBeat?
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var selectedCharacters: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(beat == nil ? "Create Plot Beat" : "Edit Plot Beat")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Beat Title").font(.system(size: 10, weight: .bold)).foregroundStyle(AppTheme.textSecondary)
                TextField("E.g., The Encounter in the Woods", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Chronological Summary").font(.system(size: 10, weight: .bold)).foregroundStyle(AppTheme.textSecondary)
                TextEditor(text: $summary)
                    .frame(height: 70)
                    .padding(4)
                    .background(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.border, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Characters Present").font(.system(size: 10, weight: .bold)).foregroundStyle(AppTheme.textSecondary)
                if book.worldCharacters.isEmpty {
                    Text("No characters found in the World Bible.")
                        .font(.system(size: 10).italic())
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(book.worldCharacters) { char in
                                let isSelected = selectedCharacters.contains(char.id)
                                Button {
                                    if isSelected {
                                        selectedCharacters.remove(char.id)
                                    } else {
                                        selectedCharacters.insert(char.id)
                                    }
                                } label: {
                                    Text(char.name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? Color(hex: subplot.colorHex) : AppTheme.border.opacity(0.5), in: Capsule())
                                        .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Spacer().frame(height: 4)

            HStack {
                if let b = beat {
                    Button {
                        book.plotBeats.removeAll { $0.id == b.id }
                        isPresented = false
                    } label: {
                        Text("Delete Beat")
                            .help("Delete this beat permanently")
                    }
                    .buttonStyle(GhostToolButtonStyle(tint: .red.opacity(0.8)))
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .help("Discard beat changes")
                }
                .buttonStyle(SecondaryPillButtonStyle())

                Button {
                    saveBeat()
                    isPresented = false
                } label: {
                    Text("Save Beat")
                        .help("Save beat modifications")
                }
                .buttonStyle(PrimaryPillButtonStyle(color: Color(hex: subplot.colorHex), fontSize: 11))
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            if let beat = beat {
                title = beat.title
                summary = beat.summary
                selectedCharacters = Set(beat.characterIDs)
            }
        }
    }

    private func saveBeat() {
        if let beat = beat {
            beat.title = title.isEmpty ? "Untitled Beat" : title
            beat.summary = summary
            beat.characterIDs = Array(selectedCharacters)
        } else {
            let newBeat = PlotBeat(
                title: title.isEmpty ? "New Beat" : title,
                summary: summary,
                subplotID: subplot.id,
                chapterID: chapter.id,
                characterIDs: Array(selectedCharacters)
            )
            book.plotBeats.append(newBeat)
        }
    }
}

struct ColorSelectionCircle: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                    .shadow(radius: isSelected ? 2 : 0)
            )
            .scaleEffect(isSelected ? 1.15 : (hovered ? 1.08 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
            .animation(.easeInOut(duration: 0.15), value: hovered)
            .onHover { hovered = $0 }
            .onTapGesture {
                action()
            }
    }
}

// MARK: - Tension & Pacing Visualizer Components

struct PacingVisualizerView: View {
    let chapters: [Chapter]
    @State private var hoveredChapterID: UUID? = nil
    @State private var activeDragChapterID: UUID? = nil

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let points = chapters.enumerated().map { i, chapter -> CGPoint in
                let x = CGFloat(i) * 236.0 + 110.0
                let normal = (chapter.tensionScore - 1.0) / 9.0
                let y = height - 15.0 - normal * (height - 30.0)
                return CGPoint(x: x, y: y)
            }

            ZStack(alignment: .topLeading) {
                // 1. Pacing Baselines Grid
                PacingGridLines(height: height)

                // 2. Continuous Bezier Line (glow + main)
                if points.count > 1 {
                    PacingBezierLine(points: points)
                }

                // 3. Node Anchors / Handles
                ForEach(Array(chapters.enumerated()), id: \.element.id) { i, chapter in
                    let pt = points[i]
                    let isHovered = hoveredChapterID == chapter.id
                    let isActiveDrag = activeDragChapterID == chapter.id

                    NodeHandleView(
                        chapter: chapter,
                        point: pt,
                        isHovered: isHovered,
                        isActiveDrag: isActiveDrag,
                        onHoverChange: { hovering in
                            if hovering {
                                hoveredChapterID = chapter.id
                            } else if hoveredChapterID == chapter.id {
                                hoveredChapterID = nil
                            }
                        },
                        onDragChange: { dragY in
                            activeDragChapterID = chapter.id
                            let normalY = (height - 15.0 - dragY) / (height - 30.0)
                            let newTension = max(1.0, min(10.0, 1.0 + normalY * 9.0))
                            chapter.tensionScore = (newTension * 10).rounded() / 10
                        },
                        onDragEnd: {
                            activeDragChapterID = nil
                        }
                    )
                }

                // 4. Hover Tooltip HUD Overlay
                if let hoveredID = hoveredChapterID,
                   let index = chapters.firstIndex(where: { $0.id == hoveredID }) {
                    let chapter = chapters[index]
                    let pt = points[index]
                    
                    TooltipHUDView(chapter: chapter)
                        .position(x: pt.x, y: pt.y - 75)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .frame(width: CGFloat(chapters.count) * 236.0 - 16.0, height: height)
        }
    }
}

struct PacingGridLines: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            // Climax baseline (Tension 10.0)
            BaselineRow(y: 15.0, label: "10.0 Climax", color: Color(hex: "#EF4444").opacity(0.15))
            
            // Action / Suspense baseline (Tension 5.5)
            BaselineRow(y: height / 2.0, label: "5.0 Action", color: Color(hex: "#F59E0B").opacity(0.1))
            
            // Exposition baseline (Tension 1.0)
            BaselineRow(y: height - 15.0, label: "1.0 Exposition", color: Color(hex: "#3DBFB8").opacity(0.15))
        }
    }

    private struct BaselineRow: View {
        let y: CGFloat
        let label: String
        let color: Color

        var body: some View {
            VStack(spacing: 0) {
                Spacer().frame(height: y - 0.5)
                HStack(spacing: 8) {
                    Text(label)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                        .padding(.leading, 8)
                    
                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(color)
                }
                .frame(height: 1)
                Spacer()
            }
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

struct PacingBezierLine: View {
    let points: [CGPoint]

    var body: some View {
        let gradient = LinearGradient(
            colors: [Color(hex: "#EC4899"), Color(hex: "#F59E0B"), Color(hex: "#3DBFB8")],
            startPoint: .leading,
            endPoint: .trailing
        )

        ZStack {
            // Neon Glow Path
            BezierPath(points: points)
                .stroke(gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .blur(radius: 4)
                .opacity(0.4)

            // Neon Core Path
            BezierPath(points: points)
                .stroke(gradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

struct BezierPath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 0 else { return path }
        
        path.move(to: points[0])
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]
            let dx = p2.x - p1.x
            
            path.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + dx/2.0, y: p1.y),
                control2: CGPoint(x: p1.x + dx/2.0, y: p2.y)
            )
        }
        return path
    }
}

struct NodeHandleView: View {
    let chapter: Chapter
    let point: CGPoint
    let isHovered: Bool
    let isActiveDrag: Bool
    let onHoverChange: (Bool) -> Void
    let onDragChange: (CGFloat) -> Void
    let onDragEnd: () -> Void

    @State private var startDragY: CGFloat? = nil

    var body: some View {
        Circle()
            .fill(AppTheme.surface)
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#EC4899"), Color(hex: "#F59E0B")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered || isActiveDrag ? 3 : 2
                    )
            )
            .shadow(
                color: Color(hex: "#EC4899").opacity(isHovered || isActiveDrag ? 0.8 : 0.4),
                radius: isHovered || isActiveDrag ? 6 : 3
            )
            .scaleEffect(isHovered || isActiveDrag ? 1.25 : 1.0)
            .position(point)
            .contentShape(Circle())
            .onHover { onHoverChange($0) }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startDragY == nil {
                            startDragY = point.y
                        }
                        if let startY = startDragY {
                            let currentY = startY + value.translation.height
                            onDragChange(currentY)
                        }
                    }
                    .onEnded { _ in
                        startDragY = nil
                        onDragEnd()
                    }
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered || isActiveDrag)
    }
}

struct TooltipHUDView: View {
    let chapter: Chapter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(chapter.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.1f", chapter.tensionScore))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(pacingColor)
            }

            HStack {
                Text(pacingBadgeText)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(pacingColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(pacingColor.opacity(0.12), in: Capsule())
                
                Spacer()
            }

            if !chapter.pacingSummary.isEmpty {
                Text(chapter.pacingSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(width: 176, alignment: .leading)
            } else {
                Text("Drag node up/down to adjust tension score manually.")
                    .font(.system(size: 9).italic())
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    .lineLimit(2)
                    .frame(width: 176, alignment: .leading)
            }
        }
        .padding(10)
        .frame(width: 200)
        .glassPanel(cornerRadius: 10)
    }

    private var pacingBadgeText: String {
        switch chapter.tensionScore {
        case 9.0...10.0: return "CLIMAX"
        case 6.0..<9.0:  return "SUSPENSE"
        case 3.0..<6.0:  return "EXPOSITION"
        default:         return "BREATHING ROOM"
        }
    }

    private var pacingColor: Color {
        switch chapter.tensionScore {
        case 9.0...10.0: return Color(hex: "#EF4444") // Red
        case 6.0..<9.0:  return Color(hex: "#F59E0B") // Orange / Amber
        case 3.0..<6.0:  return Color(hex: "#3DBFB8") // Teal / Narrate
        default:         return Color(hex: "#7C8CFF") // Blue / Write
        }
    }
}

