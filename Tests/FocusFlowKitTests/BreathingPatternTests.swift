import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct BreathingPatternTests {
    @Test func boxBreathingHasFourEqualSteps() {
        let box = BreathingPattern.all.first { $0.id == "box" }!
        #expect(box.steps.count == 4)
        #expect(box.steps.allSatisfy { $0.duration == 4 })
        #expect(box.cycleDuration == 16)
    }
    @Test func fourSevenEightHasThreeSteps() {
        let p = BreathingPattern.all.first { $0.id == "four78" }!
        #expect(p.steps.map(\.duration) == [4, 7, 8])
        #expect(p.cycleDuration == 19)
    }
    @Test func catalogIdsAreUnique() {
        #expect(Set(BreathingPattern.all.map(\.id)).count == BreathingPattern.all.count)
    }
}
