import AppKit

final class TickerWindowController {
    private let panel: NSPanel
    private let tickerView: TickerView
    private let prefs: Preferences
    private let store: ShortcutStore
    private var mouseMonitor: Any?
    private(set) var isVisible: Bool = false

    init(store: ShortcutStore, prefs: Preferences) {
        self.store = store
        self.prefs = prefs

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let height: CGFloat = 24
        let frame = NSRect(x: 0, y: screen.frame.minY, width: screen.frame.width, height: height)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        self.panel = panel

        let view = TickerView(frame: NSRect(origin: .zero, size: frame.size))
        view.opacity = CGFloat(prefs.opacity)
        view.pixelsPerSecond = CGFloat(prefs.speed)
        view.bgColor = prefs.bgColor
        view.appLabelColor = prefs.appLabelColor
        view.shortcutColor = prefs.shortcutColor
        panel.contentView = view
        self.tickerView = view

        observeScreenChanges()
        startMouseProximityWatch()
    }

    func show() {
        isVisible = prefs.tickerVisible
        if isVisible {
            panel.orderFrontRegardless()
            tickerView.start()
        } else {
            panel.orderOut(nil)
        }
    }

    func toggle() {
        if isVisible {
            panel.orderOut(nil)
            tickerView.stop()
            isVisible = false
        } else {
            panel.orderFrontRegardless()
            tickerView.start()
            isVisible = true
        }
        prefs.tickerVisible = isVisible
    }

    func updateShortcuts(_ shortcuts: [Shortcut], appLabel: String, bundleID: String) {
        tickerView.setShortcuts(shortcuts, appLabel: appLabel, bundleID: bundleID)
    }

    func applyAppearance() {
        tickerView.opacity = CGFloat(prefs.opacity)
        tickerView.pixelsPerSecond = CGFloat(prefs.speed)
        tickerView.bgColor = prefs.bgColor
        tickerView.appLabelColor = prefs.appLabelColor
        tickerView.shortcutColor = prefs.shortcutColor
        tickerView.rebuildBlocksForAppearance()
        tickerView.needsDisplay = true
    }

    // MARK: - Screen changes

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.repositionForCurrentScreen()
        }
    }

    private func repositionForCurrentScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = NSRect(x: 0, y: screen.frame.minY, width: screen.frame.width, height: panel.frame.height)
        panel.setFrame(frame, display: true)
        tickerView.frame = NSRect(origin: .zero, size: frame.size)
    }

    // MARK: - Mouse proximity fade

    private func startMouseProximityWatch() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.handleMouseMoved()
        }
        // Also poll occasionally — global monitor doesn't fire when no events flow.
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.handleMouseMoved()
        }
    }

    private func handleMouseMoved() {
        guard prefs.fadeOnMouseProximity else {
            tickerView.proximityFade = 1.0
            return
        }
        let mouse = NSEvent.mouseLocation
        let pf = panel.frame
        // Distance from mouse to panel rect (0 if inside).
        let dy: CGFloat
        if mouse.y < pf.minY { dy = pf.minY - mouse.y }
        else if mouse.y > pf.maxY { dy = mouse.y - pf.maxY }
        else { dy = 0 }
        let proximityZone: CGFloat = 80
        // Only the y-distance matters since the ticker spans width.
        let factor: CGFloat
        if dy >= proximityZone { factor = 1.0 }
        else { factor = max(0.0, dy / proximityZone) }
        tickerView.proximityFade = factor
    }
}
