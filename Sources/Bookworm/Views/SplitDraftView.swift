import SwiftUI
import AppKit

struct SplitDraftView: View {
    @Environment(Book.self) private var book
    @Bindable var chapter: Chapter
    @Binding var isPresented: Bool
    
    @State private var activeTab: Tab = .history
    @State private var snapshotDescription = ""
    @State private var selectedVersionForCompare: DraftVersion?
    
    // AI rewrite state
    @State private var aiPrompt = ""
    @State private var aiRewrittenText: String?
    @State private var isRewriting = false
    @State private var rewriteError: String?
    @State private var activePreset: String? = nil
    
    enum Tab: String, CaseIterable, Identifiable {
        case history = "History"
        case aiRewrite = "AI Rewrite"
        case comparison = "Comparison"
        
        var id: String { self.rawValue }
    }
    
    private let presets = [
        "Show, Don't Tell",
        "Gothic Tone",
        "Action-Packed",
        "Sensory Rich",
        "Dialogue Sharpener",
        "Shorten Scene"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.split.2x1")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accentWrite)
                    Text("DRAFT SPLITTING")
                        .font(AppTheme.uiFont(12, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(5)
                        .background(AppTheme.border.opacity(0.4), in: Circle())
                        .help("Close Draft Splitting")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider().background(AppTheme.border)
            
            // Tab Pill selector
            HStack(spacing: 8) {
                ForEach(Tab.allCases) { tab in
                    Button(tab.rawValue) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeTab = tab
                        }
                    }
                    .buttonStyle(NavPillButtonStyle(isActive: activeTab == tab, accent: AppTheme.accentWrite))
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .background(AppTheme.background.opacity(0.4))
            
            Divider().background(AppTheme.border)
            
            // Primary content pane
            ZStack {
                switch activeTab {
                case .history:
                    historyPane
                case .aiRewrite:
                    aiRewritePane
                case .comparison:
                    comparisonPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.surface)
        }
    }
    
    // MARK: - History Pane
    
    @ViewBuilder
    private var historyPane: some View {
        VStack(spacing: 0) {
            // Save current prose box
            VStack(alignment: .leading, spacing: 8) {
                Text("SAVE DRAFT CHECKPOINT")
                    .font(AppTheme.uiFont(10, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                HStack(spacing: 8) {
                    TextField("Label e.g., 'Before removing the duel sequence'...", text: $snapshotDescription)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                        .font(AppTheme.uiFont(12))
                    
                    Button {
                        saveCheckpoint()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Save")
                        }
                    }
                    .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentWrite, fontSize: 11))
                    .frame(width: 80)
                    .disabled(snapshotDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
            .background(AppTheme.background.opacity(0.35))
            
            Divider().background(AppTheme.border)
            
            // Checkpoints list
            if chapter.versions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                    Text("No draft versions archived yet.")
                        .font(AppTheme.editorialFont(14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Draft checkpoints allow you to take creative risks without losing original prose. Type a label above to save one.")
                        .font(AppTheme.uiFont(11))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(chapter.versions.sorted(by: { $0.timestamp > $1.timestamp })) { version in
                            versionCard(version: version)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }
    
    @ViewBuilder
    private func versionCard(version: DraftVersion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accentWrite)
                    Text(version.description)
                        .font(AppTheme.uiFont(12, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(formatDate(version.timestamp))
                    .font(AppTheme.uiFont(10))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
            }
            
            Text(version.text.prefix(120) + (version.text.count > 120 ? "..." : ""))
                .font(AppTheme.editorialFont(12))
                .foregroundStyle(AppTheme.textSecondary)
                .italic()
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(AppTheme.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
            
            HStack(spacing: 8) {
                Button {
                    selectedVersionForCompare = version
                    withAnimation(.easeInOut(duration: 0.15)) {
                        activeTab = .comparison
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                        Text("Compare")
                    }
                    .font(AppTheme.uiFont(11, weight: .semibold))
                    .foregroundStyle(AppTheme.accentWrite)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accentWrite.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                
                Button {
                    confirmRestore(version: version)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Restore Draft")
                    }
                    .font(AppTheme.uiFont(11, weight: .semibold))
                    .foregroundStyle(Color(NSColor.systemGreen))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.systemGreen).opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    chapter.versions.removeAll { $0.id == version.id }
                    if selectedVersionForCompare?.id == version.id {
                        selectedVersionForCompare = nil
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                        .padding(5)
                        .help("Delete Checkpoint")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .editorialCard(cornerRadius: 8)
    }
    
    // MARK: - AI Rewrite Pane
    
    @ViewBuilder
    private var aiRewritePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("AI PARALLEL REWRITER")
                    .font(AppTheme.uiFont(10, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Text("Query Gemini to synthesize a parallel rewrite of this chapter based on custom stylistic bounds.")
                    .font(AppTheme.editorialFont(13))
                    .foregroundStyle(AppTheme.textSecondary)
                
                // Prompt instruction editor
                VStack(alignment: .leading, spacing: 6) {
                    Text("REWRITE INSTRUCTION")
                        .font(AppTheme.uiFont(10, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                    
                    TextEditor(text: $aiPrompt)
                        .font(AppTheme.uiFont(12))
                        .frame(height: 70)
                        .padding(6)
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                }
                
                // Quick-tap presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("STYLE PRESETS")
                        .font(AppTheme.uiFont(10, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                    
                    FlowLayout(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                activePreset = preset
                                switch preset {
                                case "Show, Don't Tell":
                                    aiPrompt = "Rewrite to show events through action and visceral sensory inputs instead of narrating them."
                                case "Gothic Tone":
                                    aiPrompt = "Infuse a dark, gothic, melancholic atmosphere. Emphasize shadows, decaying architecture, and haunting imagery."
                                case "Action-Packed":
                                    aiPrompt = "Increase the narrative pace. Shorten descriptors, emphasize physical impact, and raise active verbs."
                                case "Sensory Rich":
                                    aiPrompt = "Drench the prose in sensory details: smell, auditory transients, tactile anchors, and rich visual textures."
                                case "Dialogue Sharpener":
                                    aiPrompt = "Refine dialogue exchanges to be punchier, more conversational, and heavy in subtext and character voices."
                                case "Shorten Scene":
                                    aiPrompt = "Condense the prose to be concise and impactful, stripping redundancies while keeping the narrative beat intact."
                                default:
                                    aiPrompt = preset
                                }
                            } label: {
                                Text(preset)
                            }
                            .buttonStyle(NavPillButtonStyle(isActive: activePreset == preset, accent: AppTheme.accentWrite))
                        }
                    }
                }
                
                Button {
                    runRewrite()
                } label: {
                    if isRewriting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Reimagining Scene...")
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text("Synthesize Rewrite")
                        }
                    }
                }
                .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentWrite, fontSize: 12))
                .disabled(isRewriting || aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                if let errorMsg = rewriteError {
                    Text(errorMsg)
                        .font(AppTheme.uiFont(11))
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                
                // Show AI results if available
                if let rewrite = aiRewrittenText {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider().background(AppTheme.border)
                        
                        HStack {
                            Text("AI PROPOSED REWRITE")
                                .font(AppTheme.uiFont(10, weight: .bold))
                                .foregroundStyle(AppTheme.accentWrite)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Button {
                                    acceptRewrite(rewrite)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Accept")
                                    }
                                    .font(AppTheme.uiFont(11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.systemGreen), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    aiRewrittenText = nil
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle")
                                        Text("Reject")
                                    }
                                    .font(AppTheme.uiFont(11, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.border, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        ScrollView {
                            Text(rewrite)
                                .font(AppTheme.editorialFont(13))
                                .foregroundStyle(AppTheme.textPrimary)
                                .padding(12)
                                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 250)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Comparison Pane
    
    @ViewBuilder
    private var comparisonPane: some View {
        VStack(spacing: 0) {
            // Version picker
            HStack {
                Text("COMPARE AGAINST:")
                    .font(AppTheme.uiFont(10, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                
                Spacer()
                
                Picker("", selection: $selectedVersionForCompare) {
                    Text("Select a checkpoint...").tag(nil as DraftVersion?)
                    ForEach(chapter.versions) { ver in
                        Text("\(ver.description) (\(formatDate(ver.timestamp)))")
                            .tag(ver as DraftVersion?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 250)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.background.opacity(0.35))
            
            Divider().background(AppTheme.border)
            
            if let ver = selectedVersionForCompare {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Red = Deletions", systemImage: "minus.circle")
                                .font(AppTheme.uiFont(10, weight: .bold))
                                .foregroundStyle(.red)
                            Spacer()
                            Label("Green = Additions", systemImage: "plus.circle")
                                .font(AppTheme.uiFont(10, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 4)
                        
                        Text(buildDiffAttributedString(old: ver.text, new: chapter.rawText))
                            .font(AppTheme.editorialFont(14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppTheme.surface)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                            .textSelection(.enabled)
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                    Text("No checkpoint selected for comparison.")
                        .font(AppTheme.editorialFont(14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Go to the 'History' tab and click 'Compare' next to any archived draft version to view red/green line comparisons.")
                        .font(AppTheme.uiFont(11))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveCheckpoint() {
        let text = chapter.rawText
        let desc = snapshotDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else { return }
        
        let newVersion = DraftVersion(text: text, description: desc)
        chapter.versions.append(newVersion)
        
        snapshotDescription = ""
        // Auto-select it for compare
        selectedVersionForCompare = newVersion
    }
    
    private func confirmRestore(version: DraftVersion) {
        let alert = NSAlert()
        alert.messageText = "Restore this Draft?"
        alert.informativeText = "This will replace your current text for '\(chapter.title)' with the prose from '\(version.description)'.\n\nDon't worry: Bookworm will automatically save a backup checkpoint of your current writing before restoring so nothing is lost!"
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 1. Take snapshot of current prose
            let backupLabel = "Auto-Backup before restoring '\(version.description)'"
            let backup = DraftVersion(text: chapter.rawText, description: backupLabel)
            chapter.versions.append(backup)
            
            // 2. Restore
            chapter.rawText = version.text
            
            // Refresh selection
            selectedVersionForCompare = backup
            
            let banner = NSAlert()
            banner.messageText = "Draft Restored Successfully"
            banner.informativeText = "An auto-backup of your previous prose was saved as: '\(backupLabel)'."
            banner.runModal()
        }
    }
    
    private func runRewrite() {
        isRewriting = true
        rewriteError = nil
        aiRewrittenText = nil
        
        let ledger = book.coreLedger
        let detected = ContextManager.detectCharacters(in: chapter.rawText, vault: book.worldCharacters)
        
        var charProfiles = ""
        if !detected.isEmpty {
            charProfiles += "Characters in this scene:\n"
            for c in detected {
                charProfiles += "- \(c.name): \(c.physicalDescription). Voice: \(c.personalVoice)\n"
            }
        }
        
        let systemSettings = """
        Genre: \(ledger.genre)
        Tone: \(ledger.tone)
        Tech/Magic System: \(ledger.techOrMagicSystem)
        Style Notes: \(ledger.styleNotes)
        """
        
        let prompt = """
        You are an expert creative editor and master ghostwriter. Rewrite the following chapter prose to match the user's stylistic instruction.
        
        ## CORE BOOK METRICS
        \(systemSettings)
        
        ## CHARACTER BACKGROUNDS
        \(charProfiles)
        
        ## USER INSTRUCTION
        \(aiPrompt)
        
        ## EXCERPT TO REWRITE
        \(chapter.rawText)
        
        ## YOUR TASK
        Rewrite the EXCERPT verbatim while executing the USER INSTRUCTION. 
        Ensure you maintain narrative continuity, character voices, and style bounds.
        
        Return ONLY valid JSON containing the rewritten text under the key "rewrittenText". Do not include markdown code fences, backticks, or any leading/trailing explanations.
        
        JSON Format:
        {
          "rewrittenText": "The fully rewritten chapter prose goes here..."
        }
        """
        
        Task {
            do {
                let rawResponse = try await GeminiClient.shared.generate(prompt: prompt)
                let rewritten = try parseRewriteResponse(rawResponse)
                await MainActor.run {
                    self.aiRewrittenText = rewritten
                    self.isRewriting = false
                }
            } catch {
                await MainActor.run {
                    self.rewriteError = error.localizedDescription
                    self.isRewriting = false
                }
            }
        }
    }
    
    private func parseRewriteResponse(_ raw: String) throws -> String {
        let json = GeminiClient.cleanJsonString(raw)
        
        struct ResponseObj: Decodable {
            let rewrittenText: String
        }
        
        guard let data = json.data(using: .utf8) else {
            throw GeminiError.decodingFailed("Failed to parse response text encoding.")
        }
        return try JSONDecoder().decode(ResponseObj.self, from: data).rewrittenText
    }
    
    private func acceptRewrite(_ rewrite: String) {
        // Save snapshot of current first
        let backup = DraftVersion(text: chapter.rawText, description: "Before accepting AI rewrite (\(activePreset ?? "Custom"))")
        chapter.versions.append(backup)
        
        // Overwrite
        chapter.rawText = rewrite
        aiRewrittenText = nil
        selectedVersionForCompare = backup
        
        let alert = NSAlert()
        alert.messageText = "Rewrite Accepted"
        alert.informativeText = "The AI rewrite has been merged into your live draft. A backup checkpoint of your original prose was automatically saved to History."
        alert.runModal()
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func buildDiffAttributedString(old: String, new: String) -> AttributedString {
        var result = AttributedString()
        let diffs = DiffHelper.diff(old: old, new: new)
        
        for element in diffs {
            var segment = AttributedString(element.text)
            switch element.op {
            case .equal:
                segment.foregroundColor = AppTheme.textPrimary
            case .delete:
                segment.foregroundColor = .red
                segment.strikethroughStyle = .single
                segment.strikethroughColor = .red
            case .insert:
                segment.foregroundColor = .green
                // Dynamic styling: highlight insertion
                segment.backgroundColor = Color.green.opacity(0.12)
                segment.inlinePresentationIntent = .stronglyEmphasized
            }
            result.append(segment)
        }
        
        return result
    }
}

// MARK: - Flow Layout Helper for Wrap-around tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + lineHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
    }
}
