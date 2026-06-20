import SwiftUI

struct BreakCompleteView: View {
    var onResume: () -> Void
    var onExtend: () -> Void
    var body: some View {
        SereneScaffold {
            Image(systemName: "checkmark").font(.title).foregroundStyle(SereneTokens.sage)
                .frame(width: 56, height: 56).overlay(Circle().stroke(SereneTokens.sage.opacity(0.4)))
            Text("BREAK COMPLETE").font(.system(.caption, design: .monospaced)).tracking(2)
                .foregroundStyle(SereneTokens.sage)
            Text("Break's over").font(.system(size: 40, weight: .light))
            Text("Ready to get back into deep focus?").foregroundStyle(SereneTokens.secondaryText)
            HStack(spacing: 12) {
                SereneButton("Resume Focus", filled: true, action: onResume)
                SereneButton("Extend 5 min", filled: false, action: onExtend)
            }.padding(.top, 16)
        }
    }
}

struct SereneScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            SereneTokens.surface.ignoresSafeArea()
            RadialGradient(colors: [SereneTokens.sage.opacity(0.16), .clear],
                           center: .topLeading, startRadius: 1, endRadius: 600).ignoresSafeArea()
            VStack(spacing: 16) { content }.multilineTextAlignment(.center)
        }
        .frame(minWidth: 640, minHeight: 480)
        .foregroundStyle(SereneTokens.onSurface)
    }
}

struct SereneButton: View {
    let title: String; let filled: Bool; let action: () -> Void
    init(_ title: String, filled: Bool, action: @escaping () -> Void) {
        self.title = title; self.filled = filled; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(title).frame(width: 220).padding(.vertical, 12)
                .background { if filled { Capsule().fill(SereneTokens.breathGradient) } else { Capsule().stroke(SereneTokens.mistyBlue.opacity(0.6)) } }
                .foregroundStyle(filled ? SereneTokens.surface : SereneTokens.onSurface)
        }.buttonStyle(.plain)
    }
}
