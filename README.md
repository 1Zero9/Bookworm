# Bookworm — The Modern Creative Writing Studio (v2.7.36)

[![Version](https://img.shields.io/badge/version-2.7.36-C9963A?style=flat-square)](https://github.com/1Zero9/Bookworm)
[![Build](https://img.shields.io/badge/build-39-7C8CFF?style=flat-square)](https://github.com/1Zero9/Bookworm)
[![Platform](https://img.shields.io/badge/platform-macOS%2014.0+-000000?style=flat-square)](https://developer.apple.com/macos/)

Bookworm is a premium, distraction-free macOS writing application tailored for novelists, screenwriters, and creative storytellers. Moving away from standard text editors and vintage gimmicks, it provides a literary-inspired **"Soft Editorial"** creative workspace that harmonizes long-form manuscript organization, immersive spatial design, secure local AI assistance, and professional publication workflows.

---

## 🌟 Core Features

### 1. Plot Timeline Swimlane Visualizer
An interactive narrative grid allowing authors to map out story beats across dynamic swimlanes.
- **Horizontal Swimlane Grid**: Rows represent narrative threads (Subplots) and columns represent Chapters.
- **Interactive Editing**: Double-click or trigger popovers to refine titles, summaries, and presence of character tags per narrative node.
- **Gemini Plot Auto-Mapper**: Automatically scans chapter prose using local LLM contexts to extract and map narrative beats onto the timeline.

### 2. Immersive Focus Mode (Zen Canvas)
A distraction-free writing environment built to inspire deep creative flow.
- **Minimalist Interface**: Smoothly slides and fades away all structural sidebars, progress indicators, and UI chrome on command.
- **Keystroke Acoustics DSP**: Synthesizes mechanical typewriter sounds in real-time. Features programmatically generated key-clicks and carriage-return chimes utilizing custom bandpass filters and sine sweeps over native low-latency macOS `AVAudioEngine` nodes.
- **Visual Sensory Feedback**: Gentle, pulsing cursor glows that coordinate with typing speed and smooth vertical midpoint scroll-centering.

### 3. Multi-Version Draft Splitting & Parallel Rewriting
A sophisticated draft comparison workspace that makes editing structured and visual.
- **Split-Screen Editor**: View, compare, and modify two drafts side-by-side.
- **Dynamic Programming (DP) Diffing**: Computes word-level and paragraph-level changes using a custom Longest Common Subsequence (LCS) algorithm, highlighting deletions in red and additions in green.
- **Local AI Rewriting**: Refine draft styles inline using curated presets (e.g., *"Show, Don't Tell"*, *"Gothic Tone"*) or custom structural instructions.

### 4. The Visual Director (Imagen Illustration)
Bring manuscripts to life with visual anchors.
- **Prose Distilling**: Parses chapter narratives and character ledger tags using Gemini models to synthesize evocative artistic prompts.
- **Imagen 3.0 Integration**: Leverages Google's high-fidelity Imagen model to render watercolor, oil canvas, or charcoal scene illustrations and cover designs.
- **Asynchronous Assets**: Downloads generated covers directly to `~/Documents/Bookworm/Media/` and links them dynamically into the active manuscript.

---

## 🔒 Security & Concurrency Protection

- **Secure Keychain Key Vault**: User-provided API credentials are encrypted and stored in the secure macOS Keychain via a native thread-safe `KeychainHelper` wrapper. Plaintext files and insecure configurations in `UserDefaults` are automatically migrated and wiped on first launch.
- **Mechanical DSP Concurrency Lock**: Key-click audio engines utilize low-level `NSLock` synchronization to guarantee thread-safe parameter sweeps between active rendering loops and main-thread keyboard handlers, eliminating audio race conditions.
- **JSON Code Fence Trimming**: Hardened AI response parsers feature regex cleaning routines to safely strip markdown code blocks and handle variations in returned structured JSON data.

---

## 🎨 Design Philosophy: "Soft Editorial"

Bookworm follows a tailored, high-fidelity design language engineered for readability and long writing sessions:
- **Obsidian Dark Mode**: Deep background space (`#0B0F19`), surface panels (`#131A26`), and thin separators (`#1E2536`).
- **Warm Ivory Light Mode**: Warm background tones (`#F8F7F4`) reminiscent of premium book bindings, minimizing eye strain.
- **Responsive Geometry**: Translucent sidebar panels leveraging native macOS blur materials (`.glassPanel`), rounded drop-shadow cards (`.editorialCard`), and glowing border states.
- **Visual Tooltips**: All button controls, sidebar tabs, and editing panels incorporate native AppKit-backed hover labels to maximize clarity.

---

## 🛠 Compilation & Build Pipeline

The project features a fully automated compilation and installation script. Running the build pipeline automatically bumps version numbers, maintains release documentation, compiles the project in Swift release mode, packages resources, and performs ad-hoc signing.

### 1. Build and Run the App
To compile, package, sign, and install Bookworm, execute `make-app.sh` in your terminal:
```bash
./make-app.sh
```

### 2. What Happens Automatically on Every Rebuild
When the build is triggered:
1. `bump-version.py` runs, reading the active states from `version.txt` and `build.txt`.
2. The patch version (e.g., `2.7.2` → `2.7.3`) and the build integer (e.g., `5` → `6`) are incremented.
3. The Swift source code (`Sources/Bookworm/AppTheme.swift`) is updated to reflect the new version in-app.
4. Release documentation (`RELEASE_NOTES.md` and `walkthrough.md`) is prepended with the update logs.
5. This `README.md` is updated with the current version and build badges.
6. The executable is compiled via `swift build -c release`, packaged into a self-contained `.app` bundle, codesigned, and installed to `/Applications/Bookworm.app`.

---

## 📁 Repository Structure

- `Sources/Bookworm/` — Core Swift source code.
  - `Engine/` — Core services: `GeminiClient`, `TypewriterAudioEngine`, `KeychainHelper`, `ContextManager`.
  - `Models/` — Data architecture: `Book`, `Subplot`, `DraftVersion`, `PlotTimeline`.
  - `Views/` — SwiftUI Views: `TimelineVisualizerView`, `SplitDraftView`, `ContinuousWriteView`, `AppTheme`.
- `RELEASE_NOTES.md` — History of version increments and feature logs.
- `version.txt` — Simple text file storing the current semantic version.
- `build.txt` — Simple text file storing the current build count.
- `bump-version.py` — Automated Python engine that updates source code, readmes, and logs.
- `make-app.sh` — The macOS app packaging and installation pipeline.
