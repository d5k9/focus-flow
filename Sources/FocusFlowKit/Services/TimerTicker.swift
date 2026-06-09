import Foundation

/// A periodic heartbeat. Implementations only fire `onTick`; remaining-time
/// math lives in the view model and is anchored to an absolute end-Date,
/// so missed/throttled ticks never cause drift.
public protocol TimerTicker: AnyObject {
    func start(onTick: @escaping () -> Void)
    func stop()
}

public final class DispatchSourceTimerTicker: TimerTicker {
    private var timer: DispatchSourceTimer?
    private let queue: DispatchQueue
    private let interval: TimeInterval
    private let leeway: DispatchTimeInterval

    public init(
        queue: DispatchQueue = .main,
        interval: TimeInterval = 1.0,
        leeway: DispatchTimeInterval = .milliseconds(100)
    ) {
        self.queue = queue
        self.interval = interval
        self.leeway = leeway
    }

    public func start(onTick: @escaping () -> Void) {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: leeway)
        t.setEventHandler(handler: onTick)
        timer = t
        t.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit { stop() }
}
