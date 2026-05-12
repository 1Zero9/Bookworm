import Foundation
import AppKit
import SwiftUI

// MARK: - Layout preset definitions

enum LayoutPreset: String, CaseIterable {
    case organise  = "Organise"
    case write     = "Write"
    case writeBook = "Write + Book"
    case redpen    = "Red Pen"
    case book      = "Book"
    case world     = "World Bible"

    var icon: String {
        switch self {
        case .organise:  return "sidebar.left"
        case .write:     return "doc.text"
        case .writeBook: return "rectangle.split.2x1"
        case .redpen:    return "pencil.line"
        case .book:      return "book.closed"
        case .world:     return "globe"
        }
    }

    var showSidebar: Bool { self != .book }
    var showWrite:   Bool { self != .book }
    var showRight:   Bool { self == .writeBook || self == .book }
    var isRedPen:    Bool { self == .redpen }

    var accent: Color {
        switch self {
        case .redpen: return Color(NSColor.systemOrange)
        case .book:   return AppTheme.accentNarrate
        case .world:  return AppTheme.accentWorld
        default:      return AppTheme.accentWrite
        }
    }

    var defaultSidebarWidth: CGFloat { self == .organise ? 270 : 230 }
    var defaultRightWidth:   CGFloat { self == .book ? 600 : 420 }
}

// MARK: - Layout store

final class LayoutStore: ObservableObject {
    @Published var currentPreset: LayoutPreset = .writeBook
    @Published var sidebarWidth: CGFloat = 230
    @Published var rightWidth:   CGFloat = 420
    @Published var showSidebar = true
    @Published var showWrite   = true
    @Published var showRight   = true
    @Published var reviewMode  = false

    init() { load() }

    // Apply a named preset, restoring the user's last-saved widths for it.
    func apply(_ preset: LayoutPreset) {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
            currentPreset = preset
            showSidebar   = preset.showSidebar
            showWrite     = preset.showWrite
            showRight     = preset.showRight
            reviewMode    = preset.isRedPen
            sidebarWidth  = stored("sb", preset) ?? preset.defaultSidebarWidth
            rightWidth    = stored("rp", preset) ?? preset.defaultRightWidth
        }
        persist()
    }

    // Call after any manual resize to remember the new widths.
    func persist() {
        let k = Self.screenKey
        defaults.set(currentPreset.rawValue,  forKey: "bw.preset.\(k)")
        defaults.set(Double(sidebarWidth),    forKey: "bw.\(currentPreset.rawValue).sb.\(k)")
        defaults.set(Double(rightWidth),      forKey: "bw.\(currentPreset.rawValue).rp.\(k)")
    }

    // MARK: - Private

    private let defaults = UserDefaults.standard

    private func load() {
        let k = Self.screenKey
        if let name = defaults.string(forKey: "bw.preset.\(k)"),
           let preset = LayoutPreset(rawValue: name) {
            currentPreset = preset
            showSidebar   = preset.showSidebar
            showWrite     = preset.showWrite
            showRight     = preset.showRight
            reviewMode    = preset.isRedPen
        }
        sidebarWidth = stored("sb", currentPreset) ?? currentPreset.defaultSidebarWidth
        rightWidth   = stored("rp", currentPreset) ?? currentPreset.defaultRightWidth
    }

    private func stored(_ slot: String, _ preset: LayoutPreset) -> CGFloat? {
        let v = defaults.double(forKey: "bw.\(preset.rawValue).\(slot).\(Self.screenKey)")
        return v > 0 ? CGFloat(v) : nil
    }

    // Screen-size key so different monitors get independent memories.
    static var screenKey: String {
        let s = NSScreen.main ?? NSScreen.screens.first
        return "\(Int(s?.frame.width ?? 1440))x\(Int(s?.frame.height ?? 900))"
    }
}
