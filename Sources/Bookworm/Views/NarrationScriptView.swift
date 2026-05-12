import SwiftUI

struct NarrationScriptView: View {
    @Environment(Book.self) private var book
    @EnvironmentObject private var tts: TTSManager

    var body: some View {
        if let ch = book.selectedChapter {
            if ch.narrationScript.isEmpty {
                TypewriterEmptyState(
                    message: "No Script Yet",
                    detail: "Write your story in the **purple panel**, then click the **✨ Convert to Script** button."
                )
            } else {
                ScrollView {
                    ScriptBody(
                        script: ch.narrationScript,
                        currentGroupIndex: currentGroupIndex,
                        onTapGroup: { groupIndex in
                            tts.seekToGroup(groupIndex, in: ch.narrationScript, chapterID: ch.id)
                        }
                    )
                    .padding(24)
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Select a chapter to see its script")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var currentGroupIndex: Int? {
        guard tts.isPlaying || tts.isPaused,
              tts.currentItemIndex < tts.items.count else { return nil }
        return tts.items[tts.currentItemIndex].groupIndex
    }
}

// MARK: - Typewriter empty state (shared across panels)

struct TypewriterEmptyState: View {
    let message: String
    let detail: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            if let icon = AppTheme.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .opacity(0.55)
            }
            Text(message)
                .font(AppTheme.editorialFont(22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(.init(detail))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Script rendering

private struct ParsedLine {
    enum Kind { case blank, cue, speaker, dialogue, tag, narration }
    let kind: Kind
    let text: String
    let groupIndex: Int?
}

private struct ScriptBody: View {
    let script: String
    let currentGroupIndex: Int?
    let onTapGroup: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parsed.enumerated()), id: \.offset) { _, line in
                ScriptLineRow(
                    line: line,
                    isActive: line.groupIndex != nil && line.groupIndex == currentGroupIndex,
                    onTap: line.groupIndex.map { g in { onTapGroup(g) } }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var parsed: [ParsedLine] {
        var result: [ParsedLine] = []
        var currentGroup = 0
        var bufferHasContent = false

        for raw in script.components(separatedBy: "\n") {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty {
                result.append(ParsedLine(kind: .blank, text: "", groupIndex: nil))
                continue
            }

            if t.hasPrefix("[") && t.hasSuffix("]") {
                let inner = String(t.dropFirst().dropLast())
                if bufferHasContent {
                    currentGroup += 1
                    bufferHasContent = false
                }
                let stageCues = ["SCENE OPEN", "END SCENE", "PAUSE", "DRAMATIC BEAT", "SCENE BREAK"]
                let kind: ParsedLine.Kind = stageCues.contains(inner) ? .cue : .speaker
                result.append(ParsedLine(kind: kind, text: t, groupIndex: nil))
            } else {
                let kind: ParsedLine.Kind
                if t.hasPrefix("\"") { kind = .dialogue }
                else if t.hasPrefix("  (") { kind = .tag }
                else { kind = .narration }
                result.append(ParsedLine(kind: kind, text: t, groupIndex: currentGroup))
                bufferHasContent = true
            }
        }
        return result
    }
}

private struct ScriptLineRow: View {
    let line: ParsedLine
    var isActive: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            switch line.kind {
            case .blank:
                Color.clear.frame(height: 10)

            case .cue:
                Text(line.text)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    .padding(.vertical, 1)

            case .speaker:
                Text(line.text)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.accentNarrate)
                    .padding(.top, 12)
                    .padding(.bottom, 2)

            case .dialogue:
                Text(line.text)
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundStyle(isActive ? AppTheme.accentNarrate : AppTheme.textPrimary)
                    .padding(.leading, 20)
                    .padding(.vertical, 2)

            case .tag:
                Text(line.text)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.leading, 20)

            case .narration:
                Text(line.text)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(isActive ? AppTheme.accentNarrate : AppTheme.textPrimary)
                    .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? AppTheme.accentNarrate.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}
