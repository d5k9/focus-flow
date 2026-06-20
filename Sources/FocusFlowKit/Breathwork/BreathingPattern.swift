import Foundation

public enum BreathPhaseKind: String, Sendable, Equatable {
    case inhale, holdIn, exhale, holdOut
    public var label: String {
        switch self {
        case .inhale: "Inhale"; case .holdIn: "Hold"; case .exhale: "Exhale"; case .holdOut: "Hold"
        }
    }
}

public struct BreathStep: Equatable, Sendable {
    public let kind: BreathPhaseKind
    public let duration: TimeInterval
    public init(kind: BreathPhaseKind, duration: TimeInterval) { self.kind = kind; self.duration = duration }
}

public struct BreathingPattern: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let steps: [BreathStep]
    public init(id: String, name: String, detail: String, steps: [BreathStep]) {
        self.id = id; self.name = name; self.detail = detail; self.steps = steps
    }
    public var cycleDuration: TimeInterval { steps.reduce(0) { $0 + $1.duration } }
}

public extension BreathingPattern {
    static let all: [BreathingPattern] = [
        BreathingPattern(id: "box", name: "Box Breathing", detail: "Calm and focus", steps: [
            .init(kind: .inhale, duration: 4), .init(kind: .holdIn, duration: 4),
            .init(kind: .exhale, duration: 4), .init(kind: .holdOut, duration: 4)]),
        BreathingPattern(id: "four78", name: "4-7-8 Breathing", detail: "Wind down and relax", steps: [
            .init(kind: .inhale, duration: 4), .init(kind: .holdIn, duration: 7),
            .init(kind: .exhale, duration: 8)]),
        BreathingPattern(id: "coherent", name: "Coherent Breathing", detail: "Find balance", steps: [
            .init(kind: .inhale, duration: 5), .init(kind: .exhale, duration: 5)]),
        BreathingPattern(id: "resonant", name: "Resonant", detail: "Steady rhythm", steps: [
            .init(kind: .inhale, duration: 6), .init(kind: .exhale, duration: 6)]),
    ]
}
