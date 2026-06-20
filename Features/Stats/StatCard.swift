import SwiftUI

struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(DesignTokens.labelCaps).tracking(0.5)
                .foregroundStyle(DesignTokens.secondaryText)
            Text(value).font(DesignTokens.headlineMd)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.stackTight)
        .background(DesignTokens.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 8))
    }
}
