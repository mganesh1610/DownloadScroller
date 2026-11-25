import AppKit

/// A Dock press can cause a global mouse-down, an application switch and a
/// reopen arriving separately. The physical mouse-down count identifies one
/// press even if the next click happens within the double-click interval.
enum DockClick {
    static var currentPress: UInt32? {
        let state = CGEventSourceStateID.combinedSessionState
        let count = CGEventSource.counterForEventType(state, eventType: .leftMouseDown)
        guard count != 0 else { return nil }
        if CGEventSource.buttonState(state, button: .left) { return count }
        let sinceRelease = CGEventSource.secondsSinceLastEventType(state, eventType: .leftMouseUp)
        return sinceRelease <= NSEvent.doubleClickInterval ? count : nil
    }

    static func point(of event: NSEvent) -> CGPoint {
        event.cgEvent?.unflippedLocation ?? event.locationInWindow
    }

    @MainActor static func anchor(at point: CGPoint, on screen: NSScreen, event: NSEvent? = nil) -> ShelfAnchor? {
        anchor(at: point, screen: screen.frame, visible: screen.visibleFrame,
               eventTargetIsDock: targetIsDock(event), windowIsDock: windowIsDock(at: point))
    }

    static func anchor(at point: CGPoint, screen: CGRect, visible: CGRect,
                       eventTargetIsDock: @autoclosure () -> Bool?, windowIsDock: @autoclosure () -> Bool?) -> ShelfAnchor? {
        guard let anchor = FanPlacement.dockAnchor(at: point, screen: screen, visible: visible),
              case .dock(_, let edge) = anchor else { return nil }
        // The target PID can name the receiving application even when the
        // physical press was in the space reserved for the Dock.
        switch edge {
        case .bottom where point.y < visible.minY,
             .left where point.x < visible.minX,
             .right where point.x >= visible.maxX: return anchor
        default: break
        }
        let target = eventTargetIsDock()
        if target == true { return anchor }
        if let hit = windowIsDock() { return hit ? anchor : nil }
        let inset = max(visible.minY - screen.minY, visible.minX - screen.minX, screen.maxX - visible.maxX)
        return inset <= 4 && target != false ? anchor : nil
    }

    private static func targetIsDock(_ event: NSEvent?) -> Bool? {
        guard let pid = event?.cgEvent?.getIntegerValueField(.eventTargetUnixProcessID),
              let processID = pid_t(exactly: pid), processID > 0,
              let bundle = NSRunningApplication(processIdentifier: processID)?.bundleIdentifier else { return nil }
        return bundle == "com.apple.dock"
    }

    @MainActor private static func windowIsDock(at point: CGPoint) -> Bool? {
        let number = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        guard number > 0,
              let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(number)) as? [[String: Any]],
              let pid = info.first?[kCGWindowOwnerPID as String] as? Int32,
              let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else { return nil }
        return bundle == "com.apple.dock"
    }
}

struct FanDockToggle {
    enum Action { case open, close, alreadyHandled }

    private(set) var handledPress: UInt32?
    private var outsideDismissal: UInt32?

    mutating func didDismissOutside(during press: UInt32?) { outsideDismissal = press }

    mutating func action(toggle: Bool, visible: Bool, press: UInt32?) -> Action {
        if toggle, let press, handledPress == press { return .alreadyHandled }
        let visibleAtPress = visible || (press != nil && outsideDismissal == press)
        handledPress = press
        outsideDismissal = nil
        return toggle && visibleAtPress ? .close : .open
    }
}
