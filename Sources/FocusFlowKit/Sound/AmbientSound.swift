public struct AmbientSound: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let symbol: String      // SF Symbol name
    public init(id: String, name: String, symbol: String) {
        self.id = id; self.name = name; self.symbol = symbol
    }
}

public extension AmbientSound {
    static let all: [AmbientSound] = [
        AmbientSound(id: "rain", name: "Rain", symbol: "cloud.rain"),
        AmbientSound(id: "forest", name: "Forest", symbol: "tree"),
        AmbientSound(id: "waves", name: "Waves", symbol: "water.waves"),
        AmbientSound(id: "whiteNoise", name: "White Noise", symbol: "waveform"),
    ]
}
