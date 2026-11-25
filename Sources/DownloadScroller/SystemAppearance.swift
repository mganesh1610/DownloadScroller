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
        ProcessInfo.processInfo.arguments.contains("--preview-increase-contrast") ||
        previewAppearance?.hasPrefix("contrast-") == true ||
        appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            .map { $0 == .accessibilityHighContrastAqua || $0 == .accessibilityHighContrastDarkAqua } == true
    }

    private static var previewAppearance: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--preview-appearance"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
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
        layer?.cornerCurve = .continuous
        layer?.allowsEdgeAntialiasing = true
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

/// Floating file labels use native glass with the system's legibility treatment.
/// The row draws its own selection behind the text when highlighted.
final class FanLabelSurface: NSView {
    let content = NSView()
    private let fallback = SystemMaterialView(material: .menu, radius: 12)
    private var glass: NSView?
    private var observers: [NSObjectProtocol] = []
    private var displayObserver: NSObjectProtocol?
    var highlighted = false { didSet { if highlighted != oldValue { updateStyle() } } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.allowsEdgeAntialiasing = true
        content.wantsLayer = true
        content.setAccessibilityElement(false)
        addSubview(fallback)
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let effect = NSGlassEffectView()
            effect.style = .regular
            effect.cornerRadius = 12
            effect.contentView = content
            glass = effect
            addSubview(effect)
        }
        #endif
        if glass == nil { addSubview(content) }
        setAccessibilityElement(false)
        observers.append(NotificationCenter.default.addObserver(forName: NSColor.systemColorsDidChangeNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in self?.updateStyle() })
        displayObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                                            object: nil, queue: .main) { [weak self] _ in self?.updateStyle() }
        updateStyle()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        if let displayObserver { NSWorkspace.shared.notificationCenter.removeObserver(displayObserver) }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateStyle() }
    override func layout() {
        super.layout()
        fallback.frame = bounds
        glass?.frame = bounds
        content.frame = bounds
    }

    private func updateStyle() {
        let opaque = SystemAppearance.reduceTransparency || SystemAppearance.increaseContrast(effectiveAppearance)
        let usesGlass = glass != nil && !opaque && !highlighted
        // Keep text opaque in every mode. Only the legacy material is thinned.
        fallback.alphaValue = opaque ? 1 : 0.55
        fallback.isHidden = highlighted || usesGlass
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), let effect = glass as? NSGlassEffectView {
            effect.isHidden = !usesGlass
            if !usesGlass {
                if content.superview !== self { effect.contentView = nil; addSubview(content) }
            } else if effect.contentView !== content {
                content.removeFromSuperview()
                effect.contentView = content
            }
        }
        #endif
        needsLayout = true
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
        if reduceTransparency || SystemAppearance.reduceTransparency || contrast == .increased || SystemAppearance.increaseContrast(NSApp.effectiveAppearance) {
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
