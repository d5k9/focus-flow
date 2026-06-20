import Testing
@testable import FocusFlowKit

@Suite struct BreakPromptTests {
    @Test func focusToBreakShowsStart() {
        #expect(BreakPrompt.onTransition(finished: .focus, next: .shortBreak) == .start(.shortBreak))
        #expect(BreakPrompt.onTransition(finished: .focus, next: .longBreak) == .start(.longBreak))
    }
    @Test func breakToFocusShowsComplete() {
        #expect(BreakPrompt.onTransition(finished: .shortBreak, next: .focus) == .complete)
        #expect(BreakPrompt.onTransition(finished: .longBreak, next: .focus) == .complete)
    }
}
