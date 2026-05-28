import AppKit

/// One contiguous chunk of marquee content (typically: one app's shortcuts).
struct TickerBlock {
    let id: String              // bundleID — used to dedupe consecutive blocks
    let attr: NSAttributedString
    let width: CGFloat
}

final class TickerView: NSView {
    private var blocks: [TickerBlock] = []
    /// X position of the left edge of blocks[0]. Decreases over time.
    private var headOffset: CGFloat = 0

    var pixelsPerSecond: CGFloat = 35
    var opacity: CGFloat = 0.7
    var proximityFade: CGFloat = 1.0 {
        didSet { if abs(oldValue - proximityFade) > 0.01 { needsDisplay = true } }
    }

    // Colors — set from prefs.
    var bgColor: NSColor = .black
    var appLabelColor: NSColor = .systemTeal
    var shortcutColor: NSColor = .white

    private var displayLink: CVDisplayLink?
    private var lastTick: CFTimeInterval = 0

    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func setShortcuts(_ shortcuts: [Shortcut], appLabel: String, bundleID: String) {
        let block = buildBlock(shortcuts: shortcuts, appLabel: appLabel, bundleID: bundleID)
        if blocks.isEmpty {
            blocks = [block]
            headOffset = bounds.width
        } else if let last = blocks.last, last.id == bundleID {
            // Same app — replace the queued entry so any new "learned" state takes effect on the next loop.
            blocks[blocks.count - 1] = block
        } else {
            blocks.append(block)
        }
        needsDisplay = true
    }

    func rebuildBlocksForAppearance() {
        // Re-render any current blocks with the new colors.
        // Simplest: drop everything but the active block; caller will repopulate.
        if let active = blocks.first {
            blocks = [active]
        }
        needsDisplay = true
    }

    // MARK: - Block construction

    private func buildBlock(shortcuts: [Shortcut], appLabel: String, bundleID: String) -> TickerBlock {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: appLabelColor
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: shortcutColor.withAlphaComponent(0.55)
        ]
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: shortcutColor
        ]
        let actionAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: shortcutColor.withAlphaComponent(0.85)
        ]

        let mut = NSMutableAttributedString()

        // Header
        if !appLabel.isEmpty {
            mut.append(NSAttributedString(string: "→ \(appLabel)  ", attributes: labelAttrs))
            mut.append(NSAttributedString(string: "•  ", attributes: dimAttrs))
        }

        if shortcuts.isEmpty {
            mut.append(NSAttributedString(
                string: appLabel.isEmpty ? "KeyTicker — no shortcuts loaded" : "you’ve learned every shortcut for \(appLabel) — nice",
                attributes: actionAttrs))
        } else {
            let interItem = NSAttributedString(string: "    ·    ", attributes: dimAttrs)
            for (i, s) in shortcuts.enumerated() {
                mut.append(NSAttributedString(string: s.keys, attributes: keyAttrs))
                mut.append(NSAttributedString(string: "  ", attributes: actionAttrs))
                mut.append(NSAttributedString(string: s.action, attributes: actionAttrs))
                if i < shortcuts.count - 1 {
                    mut.append(interItem)
                }
            }
        }

        // Trailing separator before next block / loop
        mut.append(NSAttributedString(string: "        ", attributes: dimAttrs))

        let width = mut.size().width
        return TickerBlock(id: bundleID, attr: mut, width: width)
    }

    // MARK: - Animation

    func start() {
        stop()
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link = link else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, ctx) -> CVReturn in
            guard let ctx = ctx else { return kCVReturnSuccess }
            let view = Unmanaged<TickerView>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { view.advance() }
            return kCVReturnSuccess
        }, context)
        CVDisplayLinkStart(link)
        displayLink = link
        lastTick = CACurrentMediaTime()
    }

    func stop() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    private func advance() {
        guard !blocks.isEmpty else { return }
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now
        headOffset -= CGFloat(dt) * pixelsPerSecond

        // Drop blocks that have fully scrolled past the left edge.
        while blocks.count > 1, headOffset <= -blocks[0].width {
            headOffset += blocks[0].width
            blocks.removeFirst()
        }

        // When only one block remains, loop it seamlessly.
        if blocks.count == 1, blocks[0].width > 0, headOffset <= -blocks[0].width {
            headOffset += blocks[0].width
        }

        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let textAlpha = opacity * proximityFade
        let bgAlpha = 0.55 * proximityFade * CGFloat(bgColor.alphaComponent)

        ctx.setFillColor(bgColor.withAlphaComponent(bgAlpha).cgColor)
        ctx.fill(bounds)

        guard !blocks.isEmpty else { return }

        let h = blocks[0].attr.size().height
        let y = (bounds.height - h) / 2

        NSGraphicsContext.saveGraphicsState()
        ctx.setAlpha(textAlpha)
        var x = headOffset
        for block in blocks {
            block.attr.draw(at: NSPoint(x: x, y: y))
            x += block.width
        }
        // If only one block, paint a second copy so the loop is seamless.
        if blocks.count == 1 {
            blocks[0].attr.draw(at: NSPoint(x: x, y: y))
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
