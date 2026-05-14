import SwiftUI
import AppKit

// Bookworm Brand — "Soft Editorial" palette (brand.md v2)
//
// Light:  Background #F7F6F3 · Surface #FFFFFF · Sidebar #EEF1F4
//         Text #1F2937 · Secondary #667085 · Border #D9DEE5
// Dark:   Background #121826 · Surface #1B2233 · Sidebar #161D2D
//         Text #F3F4F6 · Secondary #A8B0C2 · Border #2B3448
//
// Feature accents: Writing = Indigo #7C8CFF · Narration = Teal #3DBFB8
//                  Publishing = Gold #C9963A · Covers = Peach #F4B183

enum AppTheme {

    // MARK: - Light/dark adaptive backgrounds

    static let background = Color(NSColor.dynamic(
        light: NSColor(hex: "#F7F6F3"),
        dark:  NSColor(hex: "#121826")
    ))
    static let surface = Color(NSColor.textBackgroundColor)   // white / dark surface

    static let sidebar = Color(NSColor.dynamic(
        light: NSColor(hex: "#EEF1F4"),
        dark:  NSColor(hex: "#161D2D")
    ))
    static let sidebarNS = NSColor.dynamic(
        light: NSColor(hex: "#EEF1F4"),
        dark:  NSColor(hex: "#161D2D")
    )

    // MARK: - Text

    static let textPrimary = Color(NSColor.dynamic(
        light: NSColor(hex: "#1F2937"),
        dark:  NSColor(hex: "#F3F4F6")
    ))
    static let textSecondary = Color(NSColor.dynamic(
        light: NSColor(hex: "#667085"),
        dark:  NSColor(hex: "#A8B0C2")
    ))

    // MARK: - Borders & separators

    static let border = Color(NSColor.dynamic(
        light: NSColor(hex: "#D9DEE5"),
        dark:  NSColor(hex: "#2B3448")
    ))

    // MARK: - Feature accent colours

    /// Step 1 – WRITE
    static let accentWrite   = Color(NSColor.dynamic(
        light: NSColor(hex: "#7C8CFF"),
        dark:  NSColor(hex: "#9AA6FF")
    ))
    static let accentWriteNS = NSColor.dynamic(
        light: NSColor(hex: "#7C8CFF"),
        dark:  NSColor(hex: "#9AA6FF")
    )

    /// Step 3 – NARRATE
    static let accentNarrate = Color(NSColor.dynamic(
        light: NSColor(hex: "#3DBFB8"),
        dark:  NSColor(hex: "#5ED8D1")
    ))
    static let accentNarrateNS = NSColor.dynamic(
        light: NSColor(hex: "#3DBFB8"),
        dark:  NSColor(hex: "#5ED8D1")
    )

    /// Step 4 – PUBLISH
    static let accentPublish = Color(NSColor.dynamic(
        light: NSColor(hex: "#C9963A"),
        dark:  NSColor(hex: "#E0B060")
    ))

    /// World Bible — AI layer (muted purple)
    static let accentWorld = Color(NSColor.dynamic(
        light: NSColor(hex: "#9B72D0"),
        dark:  NSColor(hex: "#B48FE8")
    ))

    /// General UI accent (indigo)
    static let accent = accentWrite

    // MARK: - Legacy aliases kept for compatibility

    static let ribbon        = accentWrite          // primary CTA buttons
    static let writeBody     = surface
    static let writeBodyNS   = NSColor.textBackgroundColor
    static let scriptBody    = surface
    static let scriptAccent  = accentNarrate
    static let playBtn       = Color(hex: "#22C55E")
    static let stopBtn       = Color(hex: "#EF4444")

    // MARK: - Sidebar selection

    static let sidebarSelected = Color(NSColor.dynamic(
        light: NSColor(hex: "#7C8CFF").withAlphaComponent(0.15),
        dark:  NSColor(hex: "#9AA6FF").withAlphaComponent(0.18)
    ))
    static let sidebarSelectedNS = NSColor.dynamic(
        light: NSColor(hex: "#7C8CFF").withAlphaComponent(0.15),
        dark:  NSColor(hex: "#9AA6FF").withAlphaComponent(0.18)
    )
    static let sidebarHover = Color(NSColor.dynamic(
        light: NSColor(hex: "#1F2937").withAlphaComponent(0.06),
        dark:  NSColor(hex: "#F3F4F6").withAlphaComponent(0.07)
    ))

    // MARK: - Typography
    // UI text: SF Pro (system default — just use .system())
    // Editorial headers: New York / Georgia via .system(design: .serif)

    static func editorialFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .serif)
    }
    static func uiFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight)
    }

    // NSFont equivalents for PDF/NSTextView
    static func editorialNSFont(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }

    // MARK: - Chapter emojis
    static let chapterEmojis = ["✦","◆","▲","●","◉","◈","⬡","✿","❋","◇","⬟","✧"]
    static func emoji(for index: Int) -> String { chapterEmojis[index % chapterEmojis.count] }

    // MARK: - App icon
    static var appIcon: NSImage? = {
        Bundle.main.url(forResource: "icon", withExtension: "png", subdirectory: "Assets")
            .flatMap { NSImage(contentsOf: $0) }
    }()

    // MARK: - Version
    static let version = "v2.6.0"
}

// MARK: - Nav pill (active = filled + shadow, inactive = ghost on hover)

struct NavPillButtonStyle: ButtonStyle {
    let isActive: Bool
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        NavPillBody(config: configuration, isActive: isActive, accent: accent)
    }

    private struct NavPillBody: View {
        let config: ButtonStyleConfiguration
        let isActive: Bool
        let accent: Color
        @State private var hovered = false

        var body: some View {
            config.label
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(bgColor, in: Capsule())
                .overlay(
                    Capsule().stroke(
                        isActive ? Color.clear : (hovered ? accent.opacity(0.55) : AppTheme.border),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: isActive ? accent.opacity(hovered ? 0.55 : 0.32) : .clear,
                    radius: isActive ? (hovered ? 12 : 7) : 0,
                    y: isActive ? (hovered ? 5 : 2) : 0
                )
                .scaleEffect(config.isPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: hovered)
                .animation(.easeInOut(duration: 0.08), value: config.isPressed)
                .onHover { hovered = $0 }
        }

        private var labelColor: Color {
            if isActive { return .white }
            return hovered ? accent : AppTheme.textSecondary
        }

        private var bgColor: Color {
            if isActive { return accent }
            return hovered ? accent.opacity(0.10) : Color.clear
        }
    }
}

// MARK: - Primary CTA pill (filled, prominent shadow, hover lift)

struct PrimaryPillButtonStyle: ButtonStyle {
    var color: Color = AppTheme.accentWrite
    var fontSize: CGFloat = 13

    func makeBody(configuration: Configuration) -> some View {
        PrimaryPillBody(config: configuration, color: color, fontSize: fontSize)
    }

    private struct PrimaryPillBody: View {
        let config: ButtonStyleConfiguration
        let color: Color
        let fontSize: CGFloat
        @State private var hovered = false

        var body: some View {
            config.label
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(color, in: Capsule())
                .overlay(Capsule().fill(Color.white.opacity(hovered ? 0.10 : 0)))
                .shadow(color: color.opacity(hovered ? 0.50 : 0.30),
                        radius: hovered ? 14 : 7, y: hovered ? 5 : 3)
                .scaleEffect(config.isPressed ? 0.97 : (hovered ? 1.01 : 1.0))
                .animation(.easeInOut(duration: 0.15), value: hovered)
                .animation(.easeInOut(duration: 0.08), value: config.isPressed)
                .onHover { hovered = $0 }
        }
    }
}

// MARK: - Ghost toolbar button (icon or icon+text, rounds up on hover)

struct GhostToolButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.textSecondary

    func makeBody(configuration: Configuration) -> some View {
        GhostToolBody(config: configuration, tint: tint)
    }

    private struct GhostToolBody: View {
        let config: ButtonStyleConfiguration
        let tint: Color
        @State private var hovered = false

        var body: some View {
            config.label
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(hovered ? AppTheme.textPrimary : tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(hovered ? AppTheme.border.opacity(0.7) : .clear, in: Capsule())
                .scaleEffect(config.isPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.13), value: hovered)
                .animation(.easeInOut(duration: 0.08), value: config.isPressed)
                .onHover { hovered = $0 }
        }
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >>  8) & 0xFF) / 255
        let b = Double( v        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

// MARK: - NSColor helpers

extension NSColor {
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1) {
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(calibratedRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue:  CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { a in
            a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }
}
