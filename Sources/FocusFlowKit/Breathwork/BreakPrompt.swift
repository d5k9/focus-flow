public enum BreakPromptKind: Equatable, Sendable {
    case start(PomodoroPhase)   // a break is beginning
    case complete               // a break just ended
    case none
}

public enum BreakPrompt {
    public static func onTransition(finished: PomodoroPhase, next: PomodoroPhase) -> BreakPromptKind {
        if finished == .focus, next.isBreak { return .start(next) }
        if finished.isBreak, next == .focus { return .complete }
        return .none
    }
}
