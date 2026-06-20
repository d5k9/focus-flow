import SwiftUI

struct BreakStartView: View {
    let minutes: Int
    var onStartBreath: () -> Void
    var onStartBreak: () -> Void
    var onSkip: () -> Void

    var body: some View {
        SereneScaffold {
            Text("FOCUS COMPLETE").font(.system(.caption, design: .monospaced)).tracking(2)
                .foregroundStyle(SereneTokens.sage)
            Text("Time for a break").font(.system(size: 40, weight: .light))
            Text("You've focused well. Take \(minutes) to recharge.")
                .foregroundStyle(SereneTokens.secondaryText)
            VStack(spacing: 12) {
                SereneButton("Start Break", filled: true, action: onStartBreak)
                SereneButton("Breathe", filled: false, action: onStartBreath)
                SereneButton("Skip break", filled: false, action: onSkip)
            }.padding(.top, 16)
        }
    }
}
