import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct BreathingSessionTests {
    private var box: BreathingPattern { BreathingPattern.all.first { $0.id == "box" }! }

    @Test func startsOnInhale() {
        let s = BreathingSession(pattern: box, targetCycles: 2)
        #expect(s.currentKind == .inhale)
        #expect(s.completedCycles == 0)
        #expect(!s.isFinished)
    }
    @Test func advancesThroughStepsByElapsedTime() {
        var s = BreathingSession(pattern: box, targetCycles: 2)
        s.update(elapsed: 5)    // 0-4 inhale, 4-8 holdIn
        #expect(s.currentKind == .holdIn)
        s.update(elapsed: 13)   // 12-16 holdOut
        #expect(s.currentKind == .holdOut)
    }
    @Test func countsCompletedCycles() {
        var s = BreathingSession(pattern: box, targetCycles: 2)
        s.update(elapsed: 16)           // one full 16s cycle done
        #expect(s.completedCycles == 1)
        #expect(s.currentKind == .inhale)
    }
    @Test func finishesAfterTargetCycles() {
        var s = BreathingSession(pattern: box, targetCycles: 2)
        s.update(elapsed: 32)
        #expect(s.completedCycles == 2)
        #expect(s.isFinished)
    }
    @Test func remainingCountsDownWithinCurrentStep() {
        let s = BreathingSession(pattern: box, targetCycles: 2)
        #expect(s.remaining(elapsed: 1) == 3)   // 1s into the 4s inhale
    }
}
