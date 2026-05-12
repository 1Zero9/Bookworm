import SwiftUI
import AVFoundation

struct PlaybackBar: View {
    @EnvironmentObject private var tts: TTSManager
    @Environment(Book.self) private var book

    var body: some View {
        HStack(spacing: 0) {
            // Label + bookmark indicator
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tts.isPlaying ? AppTheme.accentNarrate : AppTheme.textSecondary)
                    .symbolEffect(.variableColor.iterative, isActive: tts.isPlaying)

                VStack(alignment: .leading, spacing: 1) {
                    Text("PLAYBACK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .tracking(0.8)

                    if tts.isPlaying || tts.isPaused, !tts.items.isEmpty {
                        Text("\(tts.currentItemIndex + 1) of \(tts.items.count) sentences")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accentNarrate)
                    } else {
                        Text(book.selectedChapter?.title ?? "Select a chapter")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 16)
            .frame(width: 160, alignment: .leading)

            separator()

            // Voice picker
            HStack(spacing: 6) {
                Image(systemName: "person.wave.2")
                    .foregroundStyle(AppTheme.textSecondary)
                    .font(.system(size: 12))

                Picker("Voice", selection: $tts.selectedVoiceID) {
                    if !tts.premiumVoices.isEmpty {
                        Section("⭐️ Premium") {
                            ForEach(tts.premiumVoices, id: \.identifier) {
                                Text($0.name).tag($0.identifier)
                            }
                        }
                    }
                    if !tts.enhancedVoices.isEmpty {
                        Section("✨ Enhanced") {
                            ForEach(tts.enhancedVoices, id: \.identifier) {
                                Text($0.name).tag($0.identifier)
                            }
                        }
                    }
                    Section("Standard") {
                        ForEach(tts.standardVoices, id: \.identifier) {
                            Text($0.name).tag($0.identifier)
                        }
                    }
                }
                .labelsHidden()
                .frame(width: 140)

                Button { tts.openVoiceSettings() } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Download better voices — System Settings → Accessibility → Spoken Content")
            }
            .padding(.horizontal, 12)

            separator()

            // Speed
            HStack(spacing: 7) {
                Image(systemName: "tortoise").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                Slider(value: $tts.rate, in: 0.25...0.65).frame(width: 80)
                Image(systemName: "hare").font(.system(size: 11)).foregroundStyle(AppTheme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 12)

            Spacer()

            // Bookmark resume button
            if let ch = book.selectedChapter,
               !tts.isPlaying, !tts.isPaused,
               let bookmarkIdx = tts.bookmarks[ch.id],
               bookmarkIdx > 0 {
                Button {
                    let script = ch.narrationScript.isEmpty ? ch.rawText : ch.narrationScript
                    if ch.narrationScript.isEmpty {
                        tts.speakRaw(script, chapterID: ch.id)
                    } else {
                        tts.speakScript(script, chapterID: ch.id, from: bookmarkIdx)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bookmark.fill").font(.system(size: 10))
                        Text("Resume").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accentNarrate)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accentNarrate.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .help("Resume from sentence \(bookmarkIdx + 1)")

                Button {
                    if let ch = book.selectedChapter { tts.clearBookmark(for: ch.id) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .help("Clear bookmark")
            }

            // Play controls
            HStack(spacing: 14) {
                // Stop
                Button { tts.stop() } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.stopBtn.opacity(tts.isPlaying || tts.isPaused ? 0.12 : 0.07))
                            .frame(width: 36, height: 36)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.stopBtn.opacity(tts.isPlaying || tts.isPaused ? 1.0 : 0.35))
                    }
                }
                .buttonStyle(.plain)
                .help("Stop")

                // Play / Pause / Resume
                Button { handlePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(playButtonColor)
                            .frame(width: 44, height: 44)
                            .shadow(color: playButtonColor.opacity(0.35), radius: 6, y: 2)
                        Image(systemName: tts.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: tts.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)
                .help(tts.isPlaying ? "Pause" : tts.isPaused ? "Resume" : "Play")
            }
            .padding(.trailing, 20)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.background)
        .overlay(alignment: .top) { Divider().background(AppTheme.border) }
    }

    private var playButtonColor: Color {
        if tts.isPlaying { return AppTheme.accentNarrate }
        if tts.isPaused  { return AppTheme.accentWrite.opacity(0.85) }
        return AppTheme.playBtn
    }

    private func separator() -> some View {
        Divider().background(AppTheme.border).padding(.vertical, 12)
    }

    private func handlePlayPause() {
        if tts.isPaused {
            tts.resume()
        } else if tts.isPlaying {
            tts.pause()
        } else {
            guard let ch = book.selectedChapter else { return }
            if ch.narrationScript.isEmpty {
                tts.speakRaw(ch.rawText, chapterID: ch.id)
            } else {
                tts.speakScript(ch.narrationScript, chapterID: ch.id)
            }
        }
    }
}
