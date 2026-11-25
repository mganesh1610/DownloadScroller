import AppKit

/// Shared geometry for sizing the floating window and its scrolling document.
enum FanMetrics {
    static let rowStride: CGFloat = 58
    static let iconInset: CGFloat = 68
    static let bottomRowCenterInset: CGFloat = 46
    static let defaultWidth: CGFloat = 560
    static let minimumWidth: CGFloat = 280
    static let canvasGutter: CGFloat = 88
    static let fileIconAndGap: CGFloat = 54
    static let labelPadding: CGFloat = 24
    static let textInset: CGFloat = 11

    static func maximumLabelWidth(in panelWidth: CGFloat) -> CGFloat {
        max(120, panelWidth - canvasGutter) - fileIconAndGap
    }

    @MainActor static func filenameLabel(_ name: String) -> NSTextField {
        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 12.5)
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        label.cell?.usesSingleLineMode = true
        label.alignment = .center
        return label
    }

    @MainActor static func setWrapping(_ wraps: Bool, on label: NSTextField) {
        label.cell?.usesSingleLineMode = !wraps
        label.cell?.wraps = wraps
        label.maximumNumberOfLines = wraps ? 0 : 1
        label.lineBreakMode = wraps ? .byCharWrapping : .byTruncatingMiddle
    }

    /// A screen edge can limit even a lone fan. Measure extra lines only for names
    /// that reach that edge, using the same text cell and insets as the actual row.
    @MainActor static func wrappedTextHeights(for names: some Sequence<String>, panelWidth: CGFloat) -> [String: CGFloat] {
        let labelWidth = maximumLabelWidth(in: panelWidth)
        let textBounds = CGRect(x: 0, y: 0, width: max(1, labelWidth - 2 * textInset), height: .greatestFiniteMagnitude)
        let single = filenameLabel("").cell!
        let wrapped = filenameLabel("")
        setWrapping(true, on: wrapped)
        var heights: [String: CGFloat] = [:]
        for name in names {
            single.stringValue = name
            if ceil(single.cellSize.width) + labelPadding > labelWidth {
                wrapped.stringValue = name
                heights[name] = ceil(wrapped.cell!.cellSize(forBounds: textBounds).height) + 3
            }
        }
        return heights
    }

    @MainActor static func widthToFit(_ names: some Sequence<String>) -> CGFloat {
        let cell = filenameLabel("").cell!
        var widest: CGFloat = 0
        for name in names {
            cell.stringValue = name
            widest = max(widest, cell.cellSize.width)
        }
        return max(minimumWidth, ceil(widest) + labelPadding + fileIconAndGap + canvasGutter)
    }

    static func topClearance(itemCount: Int, reduceMotion: Bool = false) -> CGFloat {
        reduceMotion ? 20 : min(112, max(20, CGFloat(itemCount - 1) * 14))
    }

    static func windowHeight(itemCount: Int) -> CGFloat {
        let count = max(1, itemCount)
        return min(780, max(260, CGFloat(count) * rowStride + topClearance(itemCount: count) + 120))
    }
}
