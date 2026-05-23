import SwiftUI
import AVFoundation

struct PlaybackBar: View {
    @EnvironmentObject private var tts: TTSManager
    @Environment(Book.self) private var book

    var body: some View {
        HStack(spacing: 0) {
            // Label + progress indicator
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

                    if tts.isPlaying || tts.isPaused, !tts.activeText.isEmpty {
                        let progress = Double(tts.spokenRange?.location ?? 0) / Double(max(1, tts.activeText.count)) * 100.0
                        Text(String(format: "%.0f%% read", progress))
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
                            ForEach(tts.premiumVoices) {
                                Text($0.name).tag($0.id)
                            }
                        }
                    }
                    if !tts.enhancedVoices.isEmpty {
                        Section("✨ Enhanced") {
                            ForEach(tts.enhancedVoices) {
                                Text($0.name).tag($0.id)
                            }
                        }
                    }
                    if !tts.standardVoices.isEmpty {
                        Section("Standard") {
                            ForEach(tts.standardVoices) {
                                Text($0.name).tag($0.id)
                            }
                        }
                    }
                }
                .labelsHidden()
                .frame(width: 140)

                Button { tts.openVoiceSettings() } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                        .help("Download better voices — System Settings → Accessibility → Spoken Content")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)

            separator()

            // Speed Slider only (Breathing gaps clock slider deleted per Elon Musk Step 2)
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "gauge.with.needle")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                    TactileSlider(
                        value: Binding(
                            get: { Double(tts.rate) },
                            set: { tts.rate = Float($0) }
                        ),
                        range: 0.25...0.65,
                        accentColor: AppTheme.accentNarrate
                    )
                    .frame(width: 100)
                    .help("Narration Speed")
                    Text(String(format: "%.2fx", tts.rate / 0.44)) // Narration rate relative to default
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 32, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Bookmark resume button
            if let ch = book.selectedChapter,
               !tts.isPlaying, !tts.isPaused,
               let bookmarkOffset = tts.bookmarks[ch.id],
               bookmarkOffset > 0, bookmarkOffset < ch.rawText.count {
                Button {
                    tts.speak(ch.rawText, chapterID: ch.id, fromOffset: bookmarkOffset, worldCharacters: book.worldCharacters)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bookmark.fill").font(.system(size: 10))
                        Text("Resume").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accentNarrate)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accentNarrate.opacity(0.10), in: Capsule())
                    .help("Resume from bookmark position")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)

                Button {
                    tts.clearBookmark(for: ch.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                        .help("Clear bookmark")
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }

            // Play controls
            HStack(spacing: 16) {
                // Skip Backward 10s
                Button { tts.skipBackward(seconds: 10) } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surface.opacity(0.6))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(tts.isPlaying || tts.isPaused ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.4))
                    }
                    .help("Rewind 10 seconds")
                }
                .buttonStyle(.plain)
                .disabled(!(tts.isPlaying || tts.isPaused))

                // Stop
                Button { tts.stop() } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surface.opacity(0.6))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(tts.isPlaying || tts.isPaused ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.4))
                    }
                    .help("Stop")
                }
                .buttonStyle(.plain)
                .disabled(!(tts.isPlaying || tts.isPaused))

                // Play / Pause / Resume
                Button { handlePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(playButtonColor)
                            .frame(width: 42, height: 42)
                            .shadow(color: playButtonColor.opacity(0.25), radius: 6, y: 2)
                        Image(systemName: tts.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: tts.isPlaying ? 0 : 1.5)
                    }
                    .help(tts.isPlaying ? "Pause" : tts.isPaused ? "Resume" : "Play")
                }
                .buttonStyle(.plain)

                // Skip Forward 10s
                Button { tts.skipForward(seconds: 10) } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surface.opacity(0.6))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                        Image(systemName: "goforward.10")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(tts.isPlaying || tts.isPaused ? AppTheme.textPrimary : AppTheme.textSecondary.opacity(0.4))
                    }
                    .help("Fast Forward 10 seconds")
                }
                .buttonStyle(.plain)
                .disabled(!(tts.isPlaying || tts.isPaused))
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
            tts.speak(ch.rawText, chapterID: ch.id, worldCharacters: book.worldCharacters)
        }
    }
}
