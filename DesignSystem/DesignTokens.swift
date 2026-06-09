import SwiftUI
import FocusFlowKit

extension Color {
    /// 0xRRGGBB hex initializer.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Single source of truth for the Ventura Focus look.
enum DesignTokens {
    // MARK: Surfaces (from design.md)
    static let surface = Color(hex: 0x131315)
    static let surfaceContainerLowest = Color(hex: 0x0E0E10)
    static let surfaceContainerLow = Color(hex: 0x1B1B1D)
    static let surfaceContainer = Color(hex: 0x1F1F21)
    static let surfaceContainerHigh = Color(hex: 0x2A2A2C)
    static let surfaceContainerHighest = Color(hex: 0x353437)

    // MARK: Text
    static let onSurface = Color(hex: 0xE4E2E4)        // primary text
    static let secondaryText = Color(hex: 0x8E8E93)    // metadata (HIG system gray)

    // MARK: Brand / semantic accents
    static let focusRed = Color(hex: 0xFF453A)
    static let relaxGreen = Color(hex: 0x32D74B)
    static let systemBlue = Color(hex: 0x0A84FF)

    /// Accent color for a phase: red for focus, green for breaks.
    static func accent(for phase: PomodoroPhase) -> Color {
        phase.isBreak ? relaxGreen : focusRed
    }

    // MARK: Glass overlays
    static let glassBorder = Color.white.opacity(0.15)   // 0.5px inner border
    static let ringTrack = Color.white.opacity(0.10)     // 10% white track
    static let hoverOverlay = Color.white.opacity(0.10)
    static let separator = Color.white.opacity(0.10)

    // MARK: Spacing (4px grid)
    static let unit: CGFloat = 4
    static let containerPadding: CGFloat = 16
    static let elementGap: CGFloat = 12
    static let stackTight: CGFloat = 8
    static let menuWidth: CGFloat = 280
    static let rowMinHeight: CGFloat = 44

    // MARK: Radii
    static let radiusControl: CGFloat = 8     // buttons/inputs (rounded)
    static let radiusContainer: CGFloat = 12  // primary flyout (rounded-lg)
    static let ringLineWidth: CGFloat = 8

    // MARK: Type scale (SF Pro = the SF equivalent named in the design)
    static let timerDisplay = Font.system(size: 48, weight: .semibold).monospacedDigit()
    static let headlineMd = Font.system(size: 18, weight: .semibold)
    static let bodySm = Font.system(size: 13, weight: .regular)
    static let labelCaps = Font.system(size: 10, weight: .bold)        // render uppercased
    static let monoLabel = Font.system(size: 11, weight: .medium, design: .monospaced)
}
