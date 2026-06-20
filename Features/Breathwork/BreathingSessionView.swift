import SwiftUI
import FocusFlowKit

struct BreathingSessionView: View {
    let vm: BreathingViewModel
    var onEnd: () -> Void

    var body: some View {
        ZStack {
            SereneTokens.surface.ignoresSafeArea()
            RadialGradient(colors: [SereneTokens.sage.opacity(0.18), .clear],
                           center: .center, startRadius: 1, endRadius: 480).ignoresSafeArea()
            VStack(spacing: 28) {
                Text(vm.session.pattern.name.uppercased())
                    .font(.system(.caption, design: .monospaced)).tracking(2)
                    .foregroundStyle(SereneTokens.sage)
                Text(vm.cycleText).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(SereneTokens.secondaryText)
                ZStack {
                    Circle().stroke(SereneTokens.sage.opacity(0.2), lineWidth: 6).frame(width: 240, height: 240)
                    Circle().trim(from: 0, to: vm.stepProgress)
                        .stroke(SereneTokens.sage, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 240, height: 240)
                    Text(vm.phaseLabel).font(.system(size: 44, weight: .light, design: .default))
                        .foregroundStyle(SereneTokens.onSurface)
                }
                Button(action: onEnd) {
                    Text("End Session").padding(.horizontal, 24).padding(.vertical, 10)
                        .overlay(Capsule().stroke(SereneTokens.mistyBlue, lineWidth: 1))
                }
                .buttonStyle(.plain).foregroundStyle(SereneTokens.onSurface)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }
}
