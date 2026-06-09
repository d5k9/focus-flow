import SwiftUI

/// Circular progress stroke. `progress` is 0...1.
struct ProgressRing: View {
    let progress: Double
    var tint: Color
    var lineWidth: CGFloat = DesignTokens.ringLineWidth

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignTokens.ringTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))   // start at 12 o'clock
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}

#Preview {
    ProgressRing(progress: 0.35, tint: DesignTokens.focusRed)
        .frame(width: 140, height: 140)
        .padding(40)
        .background(DesignTokens.surface)
}
