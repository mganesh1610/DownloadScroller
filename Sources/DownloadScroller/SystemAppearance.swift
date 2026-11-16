import AppKit
import SwiftUI

enum SystemAppearance {
    static var reduceTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ||
        ProcessInfo.processInfo.arguments.contains("--preview-reduce-transparency")
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            .map { $0 == .darkAqua || $0 == .accessibilityHighContrastDarkAqua } ?? false
    }

    static func increaseContrast(_ appearance: NSAppearance) -> Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ||
        appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            .map { $0 == .accessibilityHighContrastAqua || $0 == .accessibilityHighContrastDarkAqua } == true
    }

    /// Contributor previews affect this process only, never the user's settings.
    static func configurePreview() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--preview-appearance"), arguments.indices.contains(index + 1) else { return }
        let names: [String: NSAppearance.Name] = ["light": .aqua, "dark": .darkAqua,
            "contrast-light": .accessibilityHighContrastAqua, "contrast-dark": .accessibilityHighContrastDarkAqua]
        if let name = names[arguments[index + 1]] { NSApp.appearance = NSAppearance(named: name) }
    }
}

/// A real AppKit backdrop, including native vibrancy and accessibility fallbacks.
final class SystemMaterialView: NSVisualEffectView {
    private let opaqueFill = NSView()
    private var observers: [NSObjectProtocol] = []
    private var accessibilityObserver: NSObjectProtocol?

    init(material: NSVisualEffectView.Material = .popover, radius: CGFloat = 12) {
        super.init(frame: .zero)
        self.material = material
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.masksToBounds = true
        opaqueFill.wantsLayer = true
        opaqueFill.autoresizingMask = [.width, .height]
        opaqueFill.setAccessibilityElement(false)
        addSubview(opaqueFill)
        observers.append(NotificationCenter.default.addObserver(forName: NSColor.systemColorsDidChangeNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in self?.updateStyle() })
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                                                   object: nil, queue: .main) { [weak self] _ in self?.updateStyle() }
        updateStyle()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateStyle() }
    override func layout() { super.layout(); opaqueFill.frame = bounds }

    private func updateStyle() {
        let contrast = SystemAppearance.increaseContrast(effectiveAppearance)
        opaqueFill.isHidden = !SystemAppearance.reduceTransparency && !contrast
        effectiveAppearance.performAsCurrentDrawingAppearance {
            opaqueFill.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
        layer?.borderWidth = contrast ? 1 : 0
    }
}

struct NativeMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var radius: CGFloat = 18
    func makeNSView(context: Context) -> SystemMaterialView { SystemMaterialView(material: material, radius: radius) }
    func updateNSView(_ view: SystemMaterialView, context: Context) {}
}

/// Glass is reserved for floating controls. Older systems use their own material.
private struct SystemControlSurface: ViewModifier {
    var radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || SystemAppearance.reduceTransparency || contrast == .increased {
            content.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color(nsColor: .separatorColor)))
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular, in: .rect(cornerRadius: radius))
            } else {
                content.background(NativeMaterial(radius: radius))
            }
            #else
            content.background(NativeMaterial(radius: radius))
            #endif
        }
    }
}

extension View {
    func systemControlSurface(radius: CGFloat = 20) -> some View { modifier(SystemControlSurface(radius: radius)) }
}
