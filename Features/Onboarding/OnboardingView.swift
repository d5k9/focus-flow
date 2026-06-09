import SwiftUI

struct OnboardingView: View {
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.elementGap) {
            Image(systemName: "power")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DesignTokens.onSurface)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: DesignTokens.radiusControl,
                                             style: .continuous)
                    .fill(DesignTokens.surfaceContainerHigh))

            Text("FocusFlow").font(DesignTokens.headlineMd)

            Text("Your new productivity companion lives right up here in your menu bar. Click the timer icon to start your first session.")
                .font(DesignTokens.bodySm)
                .foregroundStyle(DesignTokens.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onGetStarted) {
                HStack {
                    Text("Get Started")
                    Image(systemName: "arrow.right")
                }
                .font(DesignTokens.bodySm.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: DesignTokens.radiusControl,
                                             style: .continuous)
                    .fill(DesignTokens.focusRed))
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.stackTight)
        }
        .padding(DesignTokens.containerPadding)
        .frame(width: 360)
        .background(DesignTokens.surface)
        .foregroundStyle(DesignTokens.onSurface)
    }
}
