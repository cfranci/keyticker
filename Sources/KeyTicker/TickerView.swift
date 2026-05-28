import AppKit

final class TickerView: NSView {
    private var shortcuts: [Shortcut] = []
    private var appLabel: String = ""

    /// Pixels per second the marquee scrolls.
    var pixelsPerSecond: CGFloat = 60
    /// Base opacity from user preference (0..1).
    var opacity: CGFloat = 0.7
    /// Mouse proximity multiplier (0 = mouse on ticker, 1 = far away).
    var proximityFade: CGFloat = 1.0 {
        didSet { if abs(oldValue - proximityFade) > 0.01 { needsDisplay = true } }
    }

    private var displayLink: CVDisplayLink?
    private var offsetX: CGFloat = 0
    private var lastTick: CFTimeInterval = 0
    private var renderedAttributedString: NSAttributedString = NSAttributedString(string: "")
    private var renderedWidth: CGFloat = 0
    private let gapBetweenLoops: CGFloat = 80

    override var wantsUpdateLayer: Bool { false }
    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func setShortcuts(_ shortcuts: [Shortcut], appLabel: String) {
        self.shortcuts = shortcuts
        self.appLabel = appLabel
        rebuildAttributedString()
        offsetX = bounds.width
        needsDisplay = true
    }

    private func rebuildAttributedString() {
        let prefix = NSMutableAttributedString()
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.systemTeal
        ]
        let separator: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let actionAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.lightGray
        ]

        guard !shortcuts.isEmpty else {
            let placeholder = NSAttributedString(
                string: "KeyTicker  •  \(appLabel.isEmpty ? "no shortcuts available" : "you’ve learned every shortcut for \(appLabel) — nice")",
                attributes: actionAttrs)
            renderedAttributedString = placeholder
            renderedWidth = placeholder.size().width
            return
        }

        if !appLabel.isEmpty {
            prefix.append(NSAttributedString(string: "\(appLabel)  ", attributes: labelAttrs))
            prefix.append(NSAttributedString(string: "•  ", attributes: separator))
        }

        for (i, s) in shortcuts.enumerated() {
            prefix.append(NSAttributedString(string: s.keys, attributes: keyAttrs))
            prefix.append(NSAttributedString(string: "  ", attributes: actionAttrs))
            prefix.append(NSAttributedString(string: s.action, attributes: actionAttrs))
            if i < shortcuts.count - 1 {
                prefix.append(NSAttributedString(string: "    ", attributes: separator))
                prefix.append(NSAttributedString(string: "·", attributes: separator))
                prefix.append(NSAttributedString(string: "    ", attributes: separator))
            }
        }

        renderedAttributedString = prefix
        renderedWidth = prefix.size().width
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
            DispatchQueue.main.async {
                view.advance()
            }
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
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now
        offsetX -= CGFloat(dt) * pixelsPerSecond
        let loopWidth = renderedWidth + gapBetweenLoops
        if loopWidth > 0 && offsetX <= -loopWidth {
            offsetX += loopWidth
        }
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Background gradient — black with alpha matching proximity * opacity, fading on edges
        let alpha = opacity * proximityFade
        let bgAlpha = 0.6 * alpha
        ctx.setFillColor(NSColor.black.withAlphaComponent(bgAlpha).cgColor)
        ctx.fill(bounds)

        // Draw text twice for seamless wrap
        let textY = (bounds.height - renderedAttributedString.size().height) / 2
        NSGraphicsContext.saveGraphicsState()
        ctx.setAlpha(alpha)
        renderedAttributedString.draw(at: NSPoint(x: offsetX, y: textY))
        let loopWidth = renderedWidth + gapBetweenLoops
        if loopWidth > 0 {
            renderedAttributedString.draw(at: NSPoint(x: offsetX + loopWidth, y: textY))
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
