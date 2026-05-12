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
    @State private var book = Book()
    @State private var recentBooks: [RecentBook] = []

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(book)
                .onAppear {
                    recentBooks = RecentBooksStore.shared.recents
                    if let url = RecentBooksStore.shared.lastURL {
                        book.load(from: url)
                    }
                }
                .onChange(of: book.fileURL) { _, _ in
                    recentBooks = RecentBooksStore.shared.recents
                }
        }
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Book") { book = Book() }
                    .keyboardShortcut("n")
            }

            CommandGroup(after: .newItem) {
                Button("Open…") { book.open() }
                    .keyboardShortcut("o")

                Menu("Open Recent") {
                    if recentBooks.isEmpty {
                        Text("No Recent Books")
                    } else {
                        ForEach(recentBooks.prefix(10)) { recent in
                            Button(recent.title.isEmpty
                                   ? (recent.url?.deletingPathExtension().lastPathComponent ?? "Untitled")
                                   : recent.title) {
                                if let url = recent.url { book.load(from: url) }
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

                Button("Save") { book.save() }
                    .keyboardShortcut("s")

                Button("Save As…") { book.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
