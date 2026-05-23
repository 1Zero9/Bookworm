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
        light: NSColor(hex: "#F4F5F7"),
        dark:  NSColor(hex: "#070709")
    ))
    static let surface = Color(NSColor.dynamic(
        light: NSColor.white,
        dark:  NSColor(hex: "#111115")
    ))

    static let sidebar = Color(NSColor.dynamic(
        light: NSColor(hex: "#EAECEF"),
        dark:  NSColor(hex: "#0C0C0F")
    ))
    static let sidebarNS = NSColor.dynamic(
        light: NSColor(hex: "#EAECEF"),
        dark:  NSColor(hex: "#0C0C0F")
    )

    // MARK: - Text

    static let textPrimary = Color(NSColor.dynamic(
        light: NSColor(hex: "#0F172A"),
        dark:  NSColor(hex: "#F8FAFC")
    ))
    static let textSecondary = Color(NSColor.dynamic(
        light: NSColor(hex: "#64748B"),
        dark:  NSColor(hex: "#8F94A6")
    ))

    // MARK: - Borders & separators

    static let border = Color(NSColor.dynamic(
        light: NSColor(hex: "#D2D6DC"),
        dark:  NSColor(hex: "#1C1C24")
    ))

    // MARK: - Feature accent colours

    /// Step 1 – WRITE
    static let accentWrite   = Color(NSColor.dynamic(
        light: NSColor(hex: "#0066FF"),
        dark:  NSColor(hex: "#3B82F6")
    ))
    static let accentWriteNS = NSColor.dynamic(
        light: NSColor(hex: "#0066FF"),
        dark:  NSColor(hex: "#3B82F6")
    )

    /// Step 3 – NARRATE
    static let accentNarrate = Color(NSColor.dynamic(
        light: NSColor(hex: "#059669"),
        dark:  NSColor(hex: "#10B981")
    ))
    static let accentNarrateNS = NSColor.dynamic(
        light: NSColor(hex: "#059669"),
        dark:  NSColor(hex: "#10B981")
    )

    /// Step 4 – PUBLISH
    static let accentPublish = Color(NSColor.dynamic(
        light: NSColor(hex: "#D97706"),
        dark:  NSColor(hex: "#F59E0B")
    ))

    /// World Bible — AI layer (muted accent color)
    static var accentWorld: Color {
        let k = LayoutStore.screenKey
        let raw = UserDefaults.standard.string(forKey: "bw.worldAccent.\(k)") ?? "Plum"
        let accent = WorldAccent(rawValue: raw) ?? .plum
        return Color(NSColor.dynamic(
            light: NSColor(hex: accent.hexLight),
            dark:  NSColor(hex: accent.hexDark)
        ))
    }

    /// Active / Success status indicator (Vibrant Emerald Green)
    static let success = Color(NSColor.dynamic(
        light: NSColor(hex: "#059669"),
        dark:  NSColor(hex: "#10B981")
    ))

    static let accent = accentWrite

    /// Returns a highly curated ambient glow color matching the active workspace view mode
    static func dynamicGlowColor(for mode: CenterMode) -> Color {
        switch mode {
        case .write:
            return accentWrite
        case .world:
            return accentWorld
        case .review:
            return Color(NSColor.dynamic(
                light: NSColor(hex: "#EF4444"),
                dark:  NSColor(hex: "#F87171")
            )) // Crimson Rose audit mode
        case .corkboard:
            return Color(NSColor.dynamic(
                light: NSColor(hex: "#A855F7"),
                dark:  NSColor(hex: "#C084FC")
            )) // Purple storyboard mode
        }
    }

    // MARK: - Rhythm Cadence Highlights
    static let rhythmShortNS = NSColor.dynamic(
        light: NSColor(hex: "#E8F0FE").withAlphaComponent(0.85),
        dark:  NSColor(hex: "#162D4A").withAlphaComponent(0.65)
    )
    static let rhythmLongNS = NSColor.dynamic(
        light: NSColor(hex: "#FCF3E3").withAlphaComponent(0.85),
        dark:  NSColor(hex: "#38291A").withAlphaComponent(0.65)
    )

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
        light: NSColor(hex: "#0066FF").withAlphaComponent(0.12),
        dark:  NSColor(hex: "#3B82F6").withAlphaComponent(0.15)
    ))
    static let sidebarSelectedNS = NSColor.dynamic(
        light: NSColor(hex: "#0066FF").withAlphaComponent(0.12),
        dark:  NSColor(hex: "#3B82F6").withAlphaComponent(0.15)
    )
    static let sidebarHover = Color(NSColor.dynamic(
        light: NSColor(hex: "#1F2937").withAlphaComponent(0.04),
        dark:  NSColor(hex: "#F3F4F6").withAlphaComponent(0.05)
    ))

    // MARK: - Typography
    // UI text: SF Pro (system default — just use .system())
    // Editorial headers: Monospace typewriter layout

    static func editorialFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
    static func uiFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight)
    }

    // NSFont equivalents for PDF/NSTextView
    static func editorialNSFont(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont(name: "Courier New", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
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
    static let version = "v2.7.36"
    static let build = "39"
}

// MARK: - Glass Panel Modifier
struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.10)
                            : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04),
                radius: 10, y: 4
            )
    }
}

// MARK: - Editorial Card Modifier
struct EditorialCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.04),
                radius: 8, x: 0, y: 3
            )
    }
}

// MARK: - Glowing Border Modifier
struct GlowingBorderModifier: ViewModifier {
    let color: Color
    let active: Bool
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(active ? color.opacity(0.35) : Color.clear, lineWidth: 1.2)
            )
            .shadow(
                color: active ? color.opacity(0.18) : Color.clear,
                radius: active ? radius : 0,
                y: active ? 3 : 0
            )
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 10) -> some View {
        self.modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }

    func editorialCard(cornerRadius: CGFloat = 8) -> some View {
        self.modifier(EditorialCardModifier(cornerRadius: cornerRadius))
    }

    func glowingBorder(color: Color, active: Bool = true, radius: CGFloat = 6) -> some View {
        self.modifier(GlowingBorderModifier(color: color, active: active, radius: radius))
    }
}

// MARK: - Reusable Custom Tactile Slider
struct TactileSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var label: String = ""
    var icon: String = ""
    var accentColor: Color = AppTheme.accentWrite
    
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 8) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.0)
            } else if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            GeometryReader { geo in
                let width = geo.size.width
                let radius = geo.size.height / 2
                
                // Calculate position of the thumb
                let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let thumbX = min(max(percentage * width, radius), width - radius)
                
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(AppTheme.border)
                        .frame(height: 5)
                    
                    // Active Range Fill
                    Capsule()
                        .fill(accentColor)
                        .frame(width: thumbX, height: 5)
                    
                    // Drag Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 14 : 11, height: isDragging ? 14 : 11)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(0.18),
                            radius: isDragging ? 3 : 1.5,
                            y: isDragging ? 1.5 : 1
                        )
                        .position(x: thumbX, y: geo.size.height / 2)
                        .scaleEffect(isDragging ? 1.25 : 1.0)
                        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: isDragging)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let location = gesture.location.x
                            let fraction = Double(min(max(location / width, 0.0), 1.0))
                            let newValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                            self.value = newValue
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 20)
        }
    }
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
                        isActive ? Color.clear : (hovered ? accent.opacity(0.4) : AppTheme.border),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: isActive ? accent.opacity(hovered ? 0.44 : 0.24) : .clear,
                    radius: isActive ? (hovered ? 10 : 5) : 0,
                    y: isActive ? (hovered ? 3 : 1) : 0
                )
                .scaleEffect(config.isPressed ? 0.96 : (hovered ? 1.02 : 1.0))
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
            return hovered ? accent.opacity(0.08) : Color.clear
        }
    }
}

// MARK: - Primary CTA pill (filled, prominent shadow, hover lift)

struct PrimaryPillButtonStyle: ButtonStyle {
    var color: Color = AppTheme.accentWrite
    var fontSize: CGFloat = 12

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
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(
                    color: color.opacity(hovered ? 0.44 : 0.24),
                    radius: hovered ? 10 : 5,
                    y: hovered ? 4 : 2
                )
                .scaleEffect(config.isPressed ? 0.96 : (hovered ? 1.015 : 1.0))
                .animation(.easeInOut(duration: 0.15), value: hovered)
                .animation(.easeInOut(duration: 0.08), value: config.isPressed)
                .onHover { hovered = $0 }
        }
    }
}

// MARK: - Secondary pill button style (translucent border, hover micro-glow)

struct SecondaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SecondaryPillBody(config: configuration)
    }

    private struct SecondaryPillBody: View {
        let config: ButtonStyleConfiguration
        @State private var hovered = false

        var body: some View {
            config.label
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(hovered ? AppTheme.border.opacity(0.35) : AppTheme.border.opacity(0.12), in: Capsule())
                .overlay(
                    Capsule().stroke(AppTheme.border, lineWidth: 1)
                )
                .shadow(color: AppTheme.textSecondary.opacity(hovered ? 0.08 : 0.0), radius: 6)
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
                .background(
                    Capsule()
                        .fill(hovered ? AppTheme.border.opacity(0.4) : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(hovered ? AppTheme.border : Color.clear, lineWidth: 1)
                )
                .scaleEffect(config.isPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: hovered)
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

// MARK: - Snappy Glassmorphic SwiftUI Tooltips
// Custom-engineered hover tooltips with a highly responsive 200ms delay,
// bypassing macOS standard 2-second tooltip latency.

struct TooltipModifier: ViewModifier {
    let text: String
    @State private var isHovered = false
    @State private var workItem: DispatchWorkItem? = nil

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                workItem?.cancel()
                if hovering {
                    let task = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isHovered = true
                        }
                    }
                    workItem = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20, execute: task)
                } else {
                    withAnimation(.easeOut(duration: 0.10)) {
                        isHovered = false
                    }
                }
            }
            .overlay(
                GeometryReader { geo in
                    if isHovered && !text.isEmpty {
                        Text(text)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                .ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                            .fixedSize()
                            .position(x: geo.size.width / 2, y: -22)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .allowsHitTesting(false)
            )
    }
}

extension View {
    /// Overrides standard SwiftUI `.help` to use an advanced snappy tooltip overlay,
    /// showing tooltips in 200ms instead of the standard 2-second macOS delay.
    @ViewBuilder
    func help(_ text: String) -> some View {
        self.modifier(TooltipModifier(text: text))
    }

    /// Overrides standard SwiftUI generic `.help` for generic StringProtocol types.
    @ViewBuilder
    func help<S>(_ text: S) -> some View where S : StringProtocol {
        self.modifier(TooltipModifier(text: String(text)))
    }
}

// MARK: - Curated Editorial Accent Themes for the World Bible

enum WorldAccent: String, CaseIterable, Codable {
    case plum   = "Plum"
    case sage   = "Sage"
    case rose   = "Rose"
    case breeze = "Breeze"
    case amber  = "Amber"

    var hexLight: String {
        switch self {
        case .plum:   return "#9B72D0"
        case .sage:   return "#458C5A"
        case .rose:   return "#C84C5E"
        case .breeze: return "#2A82B8"
        case .amber:  return "#C86A1B"
        }
    }

    var hexDark: String {
        switch self {
        case .plum:   return "#B48FE8"
        case .sage:   return "#6FC58E"
        case .rose:   return "#EB7B8F"
        case .breeze: return "#5CB4EB"
        case .amber:  return "#EE9D4C"
        }
    }

    var label: String {
        switch self {
        case .plum:   return "Royal Plum"
        case .sage:   return "Emerald Sage"
        case .rose:   return "Crimson Rose"
        case .breeze: return "Ocean Breeze"
        case .amber:  return "Sunset Amber"
        }
    }

    var color: Color {
        Color(NSColor.dynamic(
            light: NSColor(hex: hexLight),
            dark:  NSColor(hex: hexDark)
        ))
    }
}


