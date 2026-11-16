import Foundation

/// Interpolates coarse wheel notches; precise trackpad events stay with AppKit.
/// Time-based interpolation gives the same travel on 60 Hz and 120 Hz displays.
public struct WheelMotion {
    public private(set) var position: Double = 0
    public private(set) var target: Double = 0
    private var direction: Double = 0
    public var isMoving: Bool { abs(target - position) > 0.05 }

    public init() {}

    public mutating func reset(to position: Double) {
        self.position = position
        target = position
        direction = 0
    }

    public mutating func push(_ delta: Double, maximum: Double) {
        guard delta != 0 else { return }
        if direction * delta < 0 { target = position }
        direction = delta
        // Bound queued travel so repeated notches never leave a long scroll tail.
        target = min(max(position + min(max(target + delta - position, -280), 280), 0), max(0, maximum))
    }

    @discardableResult public mutating func advance(seconds: Double, maximum: Double) -> Double {
        target = min(max(target, 0), max(0, maximum))
        position += (target - position) * (1 - exp(-max(0, seconds) / 0.055))
        if !isMoving { position = target }
        position = min(max(position, 0), max(0, maximum))
        return position
    }
}
