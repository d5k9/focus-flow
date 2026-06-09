import Foundation

/// Abstraction over "now" so timing logic is testable with a fake.
public protocol Clock: AnyObject {
    var now: Date { get }
}

public final class SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}
