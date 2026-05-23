import SwiftUI
import AppKit

struct CoverEditorView: View {
    @Environment(Book.self) private var book
    @State private var isGenerating = false
    @State private var showPromptSheet = false
    @State private var customPrompt = ""
    @State private var generationError: String? = nil
    @State private var progressMessage = ""
    @State private var chosenAspectRatio = "3:4"
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                Spacer()

                if let cover = book.coverImage {
                    ZStack(alignment: .bottomTrailing) {
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
                        
                        // Small overlay tag indicating AI generation
                        if !cover.caption.isEmpty {
                            Text(cover.caption)
                                .font(AppTheme.uiFont(9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.65), in: Capsule())
                                .padding(10)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            pickImage()
                        } label: {
                            Text("Choose File…")
                                .help("Select a custom cover image file from your Mac")
                        }
                        .buttonStyle(SecondaryPillButtonStyle())
                        
                        Button {
                            prepareAIGeneration()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "wand.and.stars")
                                  Text("AI Re-generate Cover")
                            }
                            .help("Re-synthesize cover artwork using Gemini visual distilling and Imagen")
                        }
                        .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentPublish, fontSize: 11))
                        .frame(width: 170)
                    }
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

                        Text("Unveil Your Masterpiece")
                            .font(AppTheme.editorialFont(20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Every great novel needs a face. Set a high-quality cover photo or use Gemini AI to generate custom artwork aligned with your story.")
                            .font(AppTheme.editorialFont(13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 36)
                    .frame(maxWidth: 440)
                    .editorialCard(cornerRadius: 16)
                    .padding(.bottom, 10)

                    HStack(spacing: 12) {
                        Button {
                            pickImage()
                        } label: {
                            Text("Choose File…")
                                .help("Select a custom cover image file from your Mac")
                        }
                        .buttonStyle(SecondaryPillButtonStyle())
                        
                        Button {
                            prepareAIGeneration()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "wand.and.stars")
                                Text("AI Generate Cover")
                            }
                            .help("Use Gemini AI to design cover artwork from your narrative theme settings")
                        }
                        .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentPublish, fontSize: 12))
                        .frame(width: 160)
                    }
                }

                Spacer()

                Text("Tip: you can also drag and drop cover files directly onto your Book Preview pane.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .blur(radius: isGenerating ? 3 : 0)
            .disabled(isGenerating)
            
            // Shimmering glassmorphism loading overlay
            if isGenerating {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        
                        Text(progressMessage)
                            .font(AppTheme.uiFont(13, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                        
                        // Elegant rolling creative quotes
                        Text("“Design is the silent ambassador of your story.”")
                            .font(AppTheme.editorialFont(12))
                            .foregroundStyle(.white.opacity(0.8))
                            .italic()
                            .shadow(radius: 2)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(radius: 20)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showPromptSheet) {
            promptSetupSheet
        }
    }
    
    // MARK: - Prompt Sheet
    
    @ViewBuilder
    private var promptSetupSheet: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(AppTheme.accentPublish)
                    Text("AI COVER GENERATION")
                        .font(AppTheme.uiFont(12, weight: .bold))
                }
                Spacer()
                Button { showPromptSheet = false } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .help("Discard prompt setup")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider().background(AppTheme.border)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Customize Visual Prompt")
                        .font(AppTheme.editorialFont(16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Text("Gemini analyzed your ledger themes and drafted this detailed cover art description. Edit it to reflect your vision.")
                        .font(AppTheme.editorialFont(13))
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    TextEditor(text: $customPrompt)
                        .font(AppTheme.uiFont(12))
                        .frame(height: 100)
                        .padding(6)
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.border, lineWidth: 1))
                    
                    HStack {
                        Text("Aspect Ratio:")
                            .font(AppTheme.uiFont(12, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Picker("", selection: $chosenAspectRatio) {
                            Text("Standard Cover (3:4)").tag("3:4")
                            Text("Square (1:1)").tag("1:1")
                            Text("Landscape (16:9)").tag("16:9")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(.top, 4)
                    
                    if let err = generationError {
                        Text(err)
                            .font(AppTheme.uiFont(11))
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            showPromptSheet = false
                        } label: {
                            Text("Cancel")
                                .help("Discard prompt setup")
                        }
                        .buttonStyle(SecondaryPillButtonStyle())
                        
                        Spacer()
                        
                        Button {
                            showPromptSheet = false
                            executeAIGeneration()
                        } label: {
                            Text("Begin Synthesis")
                                .help("Begin generating custom cover artwork based on your selected prompt and aspect ratio")
                        }
                        .buttonStyle(PrimaryPillButtonStyle(color: AppTheme.accentPublish, fontSize: 12))
                        .frame(width: 140)
                        .disabled(customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 10)
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 380)
        .background(AppTheme.surface)
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
    
    private func prepareAIGeneration() {
        isGenerating = true
        progressMessage = "Analyzing narrative themes..."
        generationError = nil
        
        let sampleText = book.chapters.first?.rawText ?? ""
        
        Task {
            do {
                let distilled = try await ImagenClient.shared.distillVisualPrompt(
                    text: sampleText,
                    genre: book.coreLedger.genre,
                    styleNotes: book.coreLedger.styleNotes
                )
                await MainActor.run {
                    self.customPrompt = distilled
                    self.isGenerating = false
                    self.showPromptSheet = true
                }
            } catch {
                await MainActor.run {
                    self.customPrompt = "A breathtaking novel cover art, beautiful lighting, cinematic composition."
                    self.isGenerating = false
                    self.showPromptSheet = true
                }
            }
        }
    }
    
    private func executeAIGeneration() {
        isGenerating = true
        progressMessage = "Synthesizing artwork..."
        
        Task {
            do {
                let image = try await ImagenClient.shared.generateImage(
                    prompt: customPrompt,
                    aspectRatio: chosenAspectRatio
                )
                
                // Write generated image to disk
                ImageManager.shared.ensureMediaDirectoryExists()
                let fileName = "cover_\(UUID().uuidString.prefix(8)).png"
                let fileURL = ImageManager.mediaDirectory.appendingPathComponent(fileName)
                
                if let pngData = image.pngData() {
                    try pngData.write(to: fileURL, options: .atomic)
                }
                
                await MainActor.run {
                    let bi = BookImage(nsImage: image, caption: "AI Generated", placement: .cover)
                    book.coverImage = bi
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.generationError = error.localizedDescription
                    self.isGenerating = false
                    self.showPromptSheet = true
                }
            }
        }
    }
}
