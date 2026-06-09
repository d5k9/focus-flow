import SwiftUI

/// macOS 26 Liquid Glass surface with the design's 0.5px inner light border.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = DesignTokens.radiusContainer

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignTokens.glassBorder, lineWidth: 0.5)
            }
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = DesignTokens.radiusContainer) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}
