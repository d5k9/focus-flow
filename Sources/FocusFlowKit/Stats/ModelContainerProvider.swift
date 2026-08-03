import Foundation
import SwiftData

/// The app's single SwiftData container. Sessions and tasks share it rather
/// than opening one container each over the same store.
@MainActor
public enum AppModelContainer {
    private static var cached: ModelContainer?

    /// Builds a fresh container. Tests use `inMemory: true` to get an
    /// isolated one per test.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: SessionEntity.self, TaskEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
    }

    /// The memoized on-disk container the app runs against. Building it is
    /// what opens the store, so callers should stay lazy about asking.
    public static func shared() throws -> ModelContainer {
        if let cached { return cached }
        let container = try make()
        cached = container
        return container
    }
}
