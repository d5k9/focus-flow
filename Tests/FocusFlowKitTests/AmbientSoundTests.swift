import Testing
@testable import FocusFlowKit

@Suite struct AmbientSoundTests {
    @Test func catalogHasFourUniqueSounds() {
        let all = AmbientSound.all
        #expect(all.count == 4)
        #expect(Set(all.map(\.id)).count == 4)
        #expect(all.contains { $0.id == "rain" })
    }
}
