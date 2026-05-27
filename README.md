# Bookworm — A Quiet Novel Writing Desk (v2.7.44)

[![Version](https://img.shields.io/badge/version-2.7.45-C9963A?style=flat-square)](https://github.com/1Zero9/Bookworm)
[![Build](https://img.shields.io/badge/build-52-7C8CFF?style=flat-square)](https://github.com/1Zero9/Bookworm)
[![Platform](https://img.shields.io/badge/platform-macOS%2014.0+-000000?style=flat-square)](https://developer.apple.com/macos/)

Bookworm is a private macOS writing app for drafting, organising, and revising a novel. It is designed around the daily work of writing: open the book, move through chapters, write in a calm manuscript view, keep supporting notes nearby, and preview the result without turning the workspace into a production suite.

---

## Core Features

### 1. Quiet Manuscript Editor
Write across a continuous multi-chapter manuscript with a reading-width column, simple chapter dividers, and a left sidebar for book structure.

### 2. Novel-First Launcher
Start a new novel or open an existing `.bookworm` file. Recent books stay visible without template grids or production-studio decisions.

### 3. Focus Mode
Switch into a minimal writing surface when you want the interface to get out of the way.

### 4. Book Preview
Keep an optional rendered book preview open beside the manuscript, with zoom controls for checking the feel of the pages.

### 5. Planning and Revision Tools
World Bible, storyboard, timeline, draft history, and Red Pen review tools remain available as supporting workspaces rather than daily writing distractions.

### 6. Protected Native Saves and Markdown Export
Bookworm keeps `.bookworm` as the editable source file, creates timestamped backups before overwriting existing project files, and can export a portable chapter-by-chapter Markdown folder.

### 7. App Help and Version History
Native macOS About and Help windows provide copyright information, writing guidance, and bundled version history.

---

## Security & Local Data

- **Secure Keychain Key Vault**: User-provided API credentials are encrypted and stored in the secure macOS Keychain via a native thread-safe `KeychainHelper` wrapper. Plaintext files and insecure configurations in `UserDefaults` are automatically migrated and wiped on first launch.
- **Local Book Files**: Manuscripts are saved as `.bookworm` files and can be opened from disk or recent books.
- **Automatic Backups**: Existing `.bookworm` files are copied to a local `Bookworm Backups` folder before they are overwritten.
- **Portable Markdown Export**: Manuscripts can be exported as a folder of chapter Markdown files for long-term portability.
- **Optional AI Settings**: API credentials, where used by supporting review/planning tools, are stored in the macOS Keychain.

---

## Design Philosophy

Bookworm follows a restrained editorial design language for long writing sessions:
- **Obsidian Dark Mode**: Deep background space (`#0B0F19`), surface panels (`#131A26`), and thin separators (`#1E2536`).
- **Warm Ivory Light Mode**: Warm background tones (`#F8F7F4`) reminiscent of premium book bindings, minimizing eye strain.
- **Responsive Geometry**: Translucent sidebar panels leveraging native macOS blur materials (`.glassPanel`), rounded drop-shadow cards (`.editorialCard`), and glowing border states.
- **Reduced Chrome**: The primary writing workflow avoids permanent audio, image generation, and publishing controls.

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
  - `Engine/` — Core services: `GeminiClient`, `KeychainHelper`, `ContextManager`, local stores.
  - `Models/` — Data architecture: `Book`, `Subplot`, `DraftVersion`, `PlotTimeline`.
  - `Views/` — SwiftUI Views: `StudioLauncherView`, `ContentView`, `ContinuousWriteView`, `BookPreviewView`, planning and review views.
- `RELEASE_NOTES.md` — History of version increments and feature logs.
- `version.txt` — Simple text file storing the current semantic version.
- `build.txt` — Simple text file storing the current build count.
- `bump-version.py` — Automated Python engine that updates source code, readmes, and logs.
- `make-app.sh` — The macOS app packaging and installation pipeline.
- `make-installer.sh` — Builds a `.pkg` installer from the packaged app bundle.
