import Foundation
import AppKit
import SwiftUI

// MARK: - Center Panel Modes

enum CenterMode: String, CaseIterable, Codable {
    case write  = "Write"
    case world  = "World Bible"
    case review = "Red Pen"
    case corkboard = "Storyboard"

    var icon: String {
        switch self {
        case .write:  return "doc.text"
        case .world:  return "globe"
        case .review: return "pencil.line"
        case .corkboard: return "square.grid.3x3"
        }
    }

    var helpText: String {
        switch self {
        case .write:  return "Toggle manuscript writing editor"
        case .world:  return "Toggle world building notes, rules & character bible"
        case .review: return "Toggle review, annotations and red pen audit mode"
        case .corkboard: return "Toggle storyboard corkboard outline view"
        }
    }
}

// MARK: - Layout store

final class LayoutStore: ObservableObject {
    @Published var sidebarWidth: CGFloat = 230
    @Published var rightWidth:   CGFloat = 420
    @Published var showSidebar = true
    @Published var showRight   = true
    @Published var showWrite   = true
    @Published var focusMode   = false
    @Published var rhythmMode  = false {
        didSet {
            persist()
        }
    }
    @Published var worldAccent: WorldAccent = .plum {
        didSet {
            persist()
        }
    }

    // Center mode with reactive synchronization to reviewMode
    @Published var centerMode: CenterMode = .write {
        didSet {
            if reviewMode != (centerMode == .review) {
                reviewMode = (centerMode == .review)
            }
        }
    }

    @Published var reviewMode = false {
        didSet {
            if reviewMode {
                if centerMode != .review {
                    centerMode = .review
                }
            } else {
                if centerMode == .review {
                    centerMode = .write
                }
            }
        }
    }

    init() { load() }

    // MARK: - Navigation Actions

    func toggleSidebar() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showSidebar.toggle()
        }
        persist()
    }

    func toggleRightPanel() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showRight.toggle()
            if !showRight && !showWrite {
                // Keep the workspace active: fallback to Write center mode
                showWrite = true
                centerMode = .write
            }
        }
        persist()
    }

    func toggleCenterMode(_ mode: CenterMode) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            if showWrite && centerMode == mode {
                // Clicked the active center mode button -> toggle it OFF
                showWrite = false
                // Since center panel is hidden, the right panel MUST be visible
                showRight = true
            } else {
                // Switch to or activate the selected center mode
                showWrite = true
                centerMode = mode
            }
        }
        persist()
    }

    // MARK: - Persistence

    func persist() {
        let k = Self.screenKey
        defaults.set(showSidebar,          forKey: "bw.showSidebar.\(k)")
        defaults.set(showRight,            forKey: "bw.showRight.\(k)")
        defaults.set(showWrite,            forKey: "bw.showWrite.\(k)")
        defaults.set(centerMode.rawValue,  forKey: "bw.centerMode.\(k)")
        defaults.set(Double(sidebarWidth),  forKey: "bw.sidebarWidth.\(k)")
        defaults.set(Double(rightWidth),    forKey: "bw.rightWidth.\(k)")
        defaults.set(worldAccent.rawValue,  forKey: "bw.worldAccent.\(k)")
        defaults.set(rhythmMode,            forKey: "bw.rhythmMode.\(k)")
    }

    private let defaults = UserDefaults.standard

    private func load() {
        let k = Self.screenKey
        showSidebar = defaults.object(forKey: "bw.showSidebar.\(k)") as? Bool ?? true
        showRight   = defaults.object(forKey: "bw.showRight.\(k)") as? Bool ?? true
        showWrite   = defaults.object(forKey: "bw.showWrite.\(k)") as? Bool ?? true

        if let modeStr = defaults.string(forKey: "bw.centerMode.\(k)"),
           let mode = CenterMode(rawValue: modeStr) {
            centerMode = mode
        } else {
            centerMode = .write
        }
        reviewMode = (centerMode == .review)

        let sbW = defaults.double(forKey: "bw.sidebarWidth.\(k)")
        sidebarWidth = sbW > 0 ? CGFloat(sbW) : 230

        let rpW = defaults.double(forKey: "bw.rightWidth.\(k)")
        rightWidth = rpW > 0 ? CGFloat(rpW) : 420

        if let accentStr = defaults.string(forKey: "bw.worldAccent.\(k)"),
           let accent = WorldAccent(rawValue: accentStr) {
            worldAccent = accent
        } else {
            worldAccent = .plum
        }
        rhythmMode = defaults.object(forKey: "bw.rhythmMode.\(k)") as? Bool ?? false
    }

    // Screen-size key so different monitors get independent memories.
    static var screenKey: String {
        let s = NSScreen.main ?? NSScreen.screens.first
        return "\(Int(s?.frame.width ?? 1440))x\(Int(s?.frame.height ?? 900))"
    }
}
