import SwiftUI

/// Placeholder onboarding view. Replaced with full design in Tasks 10–13.
struct OnboardingView: View {
    var onComplete: () -> Void = {}

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to FocusFlow")
                .font(.title2.bold())
            Text("Stay focused with the Pomodoro technique.")
                .multilineTextAlignment(.center)
            Button("Get Started") { onComplete() }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 360, height: 320)
    }
}
