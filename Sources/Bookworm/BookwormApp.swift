import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let url = Bundle.main.url(forResource: "icon", withExtension: "png", subdirectory: "Assets"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }
}

@main
struct BookwormApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var launchStore = LaunchStore.shared
    @State private var recentBooks: [RecentBook] = []

    var body: some Scene {
        WindowGroup {
            Group {
                if launchStore.activeMode == .launcher {
                    StudioLauncherView()
                } else {
                    ContentView()
                        .environment(launchStore.currentBook)
                }
            }
            .onAppear {
                recentBooks = RecentBooksStore.shared.recents
                if let url = RecentBooksStore.shared.lastURL {
                    // Pre-load the book state silently so it is ready, but stay in launcher mode
                    launchStore.currentBook.load(from: url)
                }
            }
            .onChange(of: launchStore.currentBook.fileURL) { _, _ in
                recentBooks = RecentBooksStore.shared.recents
            }
        }
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Bookworm") {
                    openWindow(id: "about-bookworm")
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New Book") {
                    _ = launchStore.createNewBook(format: .novel)
                }
                .keyboardShortcut("n")
            }

            CommandGroup(after: .newItem) {
                Button("Open…") {
                    let panel = NSOpenPanel()
                    panel.title = "Open Bookworm File"
                    panel.allowedContentTypes = [.init(filenameExtension: "bookworm")!]
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        launchStore.loadBook(url: url)
                    }
                }
                .keyboardShortcut("o")

                Menu("Open Recent") {
                    if recentBooks.isEmpty {
                        Text("No Recent Books")
                    } else {
                        ForEach(recentBooks.prefix(10)) { recent in
                            Button(recent.title.isEmpty
                                   ? (recent.url?.deletingPathExtension().lastPathComponent ?? "Untitled")
                                   : recent.title) {
                                if let url = recent.url { launchStore.loadBook(url: url) }
                            }
                            .disabled(!recent.exists)
                        }
                        Divider()
                        Button("Clear Menu") {
                            recentBooks.forEach { RecentBooksStore.shared.remove($0) }
                            recentBooks = []
                        }
                    }
                }

                Divider()

                Button("Save") { launchStore.currentBook.save() }
                    .keyboardShortcut("s")

                Button("Save As…") { launchStore.currentBook.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Button("Bookworm Help") {
                    openWindow(id: "bookworm-help")
                }
                .keyboardShortcut("?")

                Button("Version History") {
                    openWindow(id: "bookworm-help")
                }
            }
        }

        Window("About Bookworm", id: "about-bookworm") {
            AboutBookwormView()
        }
        .windowResizability(.contentSize)

        Window("Bookworm Help & Version History", id: "bookworm-help") {
            BookwormHelpView()
        }
        .windowResizability(.contentSize)
    }
}
