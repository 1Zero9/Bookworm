import SwiftUI
import AppKit

// MARK: - Interactive Antigravity Workspace Layout
struct AntigravityWorkspaceView: View {
    @Environment(Book.self) private var book
    
    @State private var selectedCharacterID: UUID? = nil
    @State private var selectedSeedID: UUID? = nil
    @State private var activeChapter: Int = 1
    
    var body: some View {
        Group {
            if book.worldCharacters.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    // LEFT PANE: High-Density Timeline & Arc Simulator
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ARC SIMULATOR: \(book.title.uppercased())")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Tactile trajectory visualizer & context binder")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Dynamic Chapter Context Stepper
                            HStack(spacing: 6) {
                                Button {
                                    if activeChapter > 1 {
                                        withAnimation(.easeInOut) {
                                            activeChapter -= 1
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .frame(width: 24, height: 24)
                                        .background(AppTheme.border.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .disabled(activeChapter <= 1)
                                .help("Previous chapter context")
                                
                                Text("CHAP. CONTEXT: \(String(format: "%02d", activeChapter))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppTheme.accentWorld.opacity(0.75))
                                    .cornerRadius(4)
                                    .shadow(color: AppTheme.accentWorld.opacity(0.3), radius: 4)
                                
                                Button {
                                    if activeChapter < max(1, book.chapters.count) {
                                        withAnimation(.easeInOut) {
                                            activeChapter += 1
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .frame(width: 24, height: 24)
                                        .background(AppTheme.border.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .disabled(activeChapter >= max(1, book.chapters.count))
                                .help("Next chapter context")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Canvas Simulator area for Arc lines
                        ZStack {
                            AppTheme.border.opacity(0.1)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                            
                            // Dynamic character tracks representing character lines
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(book.worldCharacters.sorted(by: { $0.order < $1.order })) { character in
                                        let isSelected = selectedCharacterID == character.id || isLinkedToSelectedSeed(characterID: character.id)
                                        let isDimmed = selectedCharacterID != nil && selectedCharacterID != character.id && !isLinkedToSelectedSeed(characterID: character.id)
                                        let charThemeColor = themeColor(for: character)
                                        
                                        InteractiveArcRow(
                                            character: character,
                                            isSelected: isSelected,
                                            isDimmed: isDimmed,
                                            themeColor: charThemeColor
                                        ) {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                selectedSeedID = nil
                                                selectedCharacterID = character.id
                                            }
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                        .padding([.horizontal, .bottom])
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.background)
                    
                    Divider()
                        .background(AppTheme.border)
                    
                    // RIGHT PANE: The Wide High-Density Command Interface (Fixed 450pt)
                    rightPane
                }
            }
        }
        .onAppear {
            if selectedCharacterID == nil {
                selectedCharacterID = book.worldCharacters.sorted(by: { $0.order < $1.order }).first?.id
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accentWorld.opacity(0.4))
            Text("Arc Simulator Inactive")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Create profiles in the Characters tab to launch the timeline arc simulator.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
    
    // MARK: - Right Pane Container
    @ViewBuilder
    private var rightPane: some View {
        if let char = activeChar {
            let charThemeColor = themeColor(for: char)
            
            VStack(spacing: 0) {
                // Tab Navigation simulation inside HUD sidebar
                HStack(spacing: 0) {
                    Text("CHARACTER CARD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.border.opacity(0.15))
                        .foregroundColor(charThemeColor)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(charThemeColor).frame(height: 2)
                        }
                    
                    Text("NOTEPAD HOPPER")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. Header & ID Block
                        HStack(alignment: .top, spacing: 15) {
                            if char.hasImage {
                                Image(nsImage: char.resolvedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(charThemeColor.opacity(0.5), lineWidth: 1)
                                    )
                                    .help("Double click full-size portrait")
                            } else {
                                Rectangle()
                                    .fill(charThemeColor.opacity(0.1))
                                    .frame(width: 90, height: 90)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(charThemeColor.opacity(0.5), lineWidth: 1)
                                    )
                                    .overlay(
                                        Text("1:1 IMG")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(charThemeColor)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ID: \(char.id.uuidString.prefix(8).uppercased())")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(AppTheme.textSecondary)
                                Text(char.name.uppercased())
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                        }
                        .padding(.top, 8)
                        
                        // 2. High-Density Horizontal Stats Grid
                        HStack(spacing: 10) {
                            StatBox(label: "TECH", val: statValue(for: "tech", in: char), color: charThemeColor)
                            StatBox(label: "STAB", val: statValue(for: "stab", in: char), color: charThemeColor)
                            StatBox(label: "RESO", val: statValue(for: "reso", in: char), color: charThemeColor)
                        }
                        
                        Divider().background(charThemeColor.opacity(0.3))
                        
                        // 3. Structured Content Blocks
                        VStack(spacing: 16) {
                            CardSection(
                                title: "1. BIOGRAPHY",
                                text: char.biography.isEmpty ? "No biographical background synchronized." : char.biography,
                                color: charThemeColor
                            )
                            
                            CardSection(
                                title: "2. SENSORY ANCHORS",
                                text: char.sensoryAnchors.isEmpty ? "No sensory anchors or cues mapped." : char.sensoryAnchors,
                                color: charThemeColor
                            )
                            
                            CardSection(
                                title: "3. PSYCHOLOGICAL PROFILE",
                                text: char.psychologicalProfile.isEmpty ? "No core behavior profile tracked." : char.psychologicalProfile,
                                color: charThemeColor
                            )
                        }
                        
                        Divider().background(charThemeColor.opacity(0.3))
                        
                        // 4. Notepad Seeds
                        Text("ASSOCIATED NARRATIVE SEEDS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)
                            .tracking(0.5)
                        
                        let associatedBeats = book.plotBeats.filter { $0.characterIDs.contains(char.id) }
                        
                        if associatedBeats.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("NO REGISTERED SEEDS")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                                Text("Add story events in the Plot Timeline and assign this character to link them dynamically.")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                    .lineSpacing(2)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.01))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.border.opacity(0.2), lineWidth: 1)
                            )
                        } else {
                            ForEach(associatedBeats) { beat in
                                let isSelected = selectedSeedID == beat.id
                                let targetChOrder = (book.chapters.first(where: { $0.id == beat.chapterID })?.order ?? 0) + 1
                                let subplotName = book.subplots.first(where: { $0.id == beat.subplotID })?.name ?? "Plot"
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(beat.title.uppercased())
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Text("CH \(targetChOrder)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(charThemeColor)
                                            .bold()
                                    }
                                    
                                    if !beat.summary.isEmpty {
                                        Text(beat.summary)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(AppTheme.textSecondary)
                                            .lineSpacing(3)
                                    }
                                    
                                    HStack {
                                        Text(subplotName.uppercased())
                                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(charThemeColor.opacity(0.12))
                                            .foregroundColor(charThemeColor)
                                            .cornerRadius(3)
                                        
                                        Spacer()
                                        
                                        // Count of other characters on this seed
                                        let otherCount = beat.characterIDs.filter { $0 != char.id }.count
                                        if otherCount > 0 {
                                            Text("+\(otherCount) LINKED")
                                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(12)
                                .background(isSelected ? charThemeColor.opacity(0.12) : AppTheme.surface.opacity(0.4))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? charThemeColor : AppTheme.border.opacity(0.2), lineWidth: 1)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        if selectedSeedID == beat.id {
                                            selectedSeedID = nil
                                        } else {
                                            selectedSeedID = beat.id
                                            activeChapter = targetChOrder
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 450)
            .background(AppTheme.surface)
            .transition(.move(edge: .trailing))
        } else {
            VStack {
                Text("Select a character track to display profile card details.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(width: 450)
            .background(AppTheme.surface)
        }
    }
    
    // MARK: - Safely Resolved Active Character
    private var activeChar: WorldCharacter? {
        if let id = selectedCharacterID, let char = book.worldCharacters.first(where: { $0.id == id }) {
            return char
        }
        return book.worldCharacters.sorted(by: { $0.order < $1.order }).first
    }
    
    // MARK: - Helper Methods
    private func isLinkedToSelectedSeed(characterID: UUID) -> Bool {
        guard let seedID = selectedSeedID, let seed = book.plotBeats.first(where: { $0.id == seedID }) else { return false }
        return seed.characterIDs.contains(characterID)
    }
    
    private func themeColor(for character: WorldCharacter) -> Color {
        let colors: [Color] = [.orange, .purple, .cyan, .teal, .indigo, .pink, .yellow, .green]
        let baseColor = colors[abs(character.id.hashValue) % colors.count]
        let resoVal = statValue(for: "reso", in: character)
        if resoVal > 80 { return .purple }
        return baseColor
    }
    
    private func statValue(for key: String, in character: WorldCharacter) -> Int {
        if let stat = character.stats.first(where: { $0.key.localizedCaseInsensitiveContains(key) }),
           let val = Int(stat.value.filter { $0.isNumber }) {
            return min(100, max(0, val))
        }
        
        let hash = abs(character.id.hashValue)
        if key.localizedCaseInsensitiveContains("tech") {
            return (hash % 36) + 60
        } else if key.localizedCaseInsensitiveContains("stab") {
            return ((hash / 3) % 40) + 50
        } else if key.localizedCaseInsensitiveContains("reso") {
            return ((hash / 7) % 55) + 40
        }
        return 75
    }
}

// MARK: - Interactive track links representing character lines
struct InteractiveArcRow: View {
    let character: WorldCharacter
    var isSelected: Bool
    var isDimmed: Bool
    let themeColor: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(character.name.isEmpty ? "UNNAMED PROFILE" : character.name.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                
                Spacer()
                
                // Track bar simulating the timeline path glow
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.border.opacity(0.2))
                        .frame(height: isSelected ? 8 : 4)
                    
                    Capsule()
                        .fill(themeColor)
                        .frame(width: isSelected ? 180 : 80, height: isSelected ? 8 : 4)
                        .shadow(color: themeColor, radius: isSelected ? 8 : 0)
                }
                .frame(width: 200)
            }
            .padding(14)
            .background(isSelected ? themeColor.opacity(0.08) : Color.clear)
            .cornerRadius(6)
            .opacity(isDimmed ? 0.3 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - StatBox component
struct StatBox: View {
    let label: String
    let val: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(AppTheme.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(val)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                Text("%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.border.opacity(0.12))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - CardSection content blocks
struct CardSection: View {
    let title: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .tracking(0.5)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.border.opacity(0.06))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.border.opacity(0.2), lineWidth: 1)
        )
    }
}
