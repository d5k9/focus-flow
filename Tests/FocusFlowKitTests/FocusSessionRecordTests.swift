import Foundation
import Testing
@testable import FocusFlowKit

@Suite struct FocusSessionRecordTests {
    @Test func storesItsFields() {
        let start = Date(timeIntervalSince1970: 1_000)
        let r = FocusSessionRecord(id: UUID(), startedAt: start, duration: 1_500)
        #expect(r.startedAt == start)
        #expect(r.duration == 1_500)
    }
}
