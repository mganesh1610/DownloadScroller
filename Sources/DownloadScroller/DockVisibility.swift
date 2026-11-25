import Combine
import Foundation

@MainActor
final class DockVisibility: ObservableObject {
    @Published private(set) var isVisible: Bool
    private let defaults: UserDefaults
    private let apply: (Bool) -> Bool
    private let key = "showAppInDock"

    init(defaults: UserDefaults = .standard, apply: @escaping (Bool) -> Bool) {
        self.defaults = defaults
        self.apply = apply
        isVisible = defaults.object(forKey: key) as? Bool ?? true
    }

    @discardableResult
    func setVisible(_ visible: Bool) -> Bool {
        guard apply(visible) else { return false }
        isVisible = visible
        defaults.set(visible, forKey: key)
        return true
    }

    func restore() {
        if !setVisible(isVisible) { _ = setVisible(true) }
    }
}
