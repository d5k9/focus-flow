import SwiftUI

enum SereneTokens {
    static let surface = Color(red: 0.07, green: 0.08, blue: 0.086)   // #121416
    static let onSurface = Color(red: 0.886, green: 0.886, blue: 0.898)
    static let sage = Color(red: 0.729, green: 0.796, blue: 0.71)     // #bacbb5
    static let mistyBlue = Color(red: 0.698, green: 0.792, blue: 0.847) // #b2cad8
    static let secondaryText = Color(red: 0.769, green: 0.784, blue: 0.749)
    static var breathGradient: LinearGradient {
        LinearGradient(colors: [sage, mistyBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
