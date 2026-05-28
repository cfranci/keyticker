import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var tickerController: TickerWindowController!
    private var appMonitor: AppMonitor!
    private var store: ShortcutStore!
    private var prefs: Preferences!
    private var shortcutsWindow: NSWindow?
    private var colorsWindow: NSWindow?

    /// Globals the user has indicated they already know — auto-marked as learned on first launch.
    /// Anyone else cloning the repo can edit this list (or just check/uncheck via Manage Shortcuts).
    private let knownGlobalsToSeed: [String] = [
        "⌘ W|Close window",
        "⌘ Q|Quit app",
        "⌘ Tab|Switch between apps",
        "⌘ Space|Spotlight search"
        // ⌘ C / V / X / R / S / A are app-level, not in the global JSON — they're already in app-specific sets
        // and get filtered out per-app when the user marks them learned there. Add per-app seeds later if needed.
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        prefs = Preferences()
        store = ShortcutStore()
        prefs.seedKnownGlobalsIfNeeded(knownGlobalsToSeed)
        tickerController = TickerWindowController(store: store, prefs: prefs)
        appMonitor = AppMonitor { [weak self] bundleID, name in
            self?.handleAppChange(bundleID: bundleID, name: name)
        }

        setupStatusItem()
        tickerController.show()
        appMonitor.start()
        // Trigger initial load with current frontmost app
        if let app = NSWorkspace.shared.frontmostApplication {
            handleAppChange(bundleID: app.bundleIdentifier, name: app.localizedName ?? "")
        }
    }

    private func handleAppChange(bundleID: String?, name: String) {
        let bid = bundleID ?? "_global"
        if prefs.isAppExcluded(bid) {
            tickerController.updateShortcuts([], appLabel: name, bundleID: bid)
            return
        }
        // shortcuts(for:) returns app-specific shortcuts followed by globals (or globals only).
        // Filter learned at the granularity of where the shortcut came from:
        //   - app-specific ones are filtered against bid's learned set
        //   - global ones are filtered against "_global" learned set
        let appSpecific = store.appSpecificShortcuts(for: bid)
            .filter { !prefs.isLearned(bundleID: bid, shortcutID: $0.id) }
        let globals = store.globalShortcuts
            .filter { !prefs.isLearned(bundleID: "_global", shortcutID: $0.id) }
        tickerController.updateShortcuts(appSpecific + globals, appLabel: name, bundleID: bid)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⌘"
            button.toolTip = "KeyTicker"
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let visibleItem = NSMenuItem(
            title: tickerController.isVisible ? "Hide Ticker" : "Show Ticker",
            action: #selector(toggleVisible), keyEquivalent: "")
        visibleItem.target = self
        menu.addItem(visibleItem)

        menu.addItem(.separator())

        // Current app section
        let currentApp = NSWorkspace.shared.frontmostApplication
        let appName = currentApp?.localizedName ?? "—"
        let bid = currentApp?.bundleIdentifier ?? "_global"
        let appHeader = NSMenuItem(title: "Current: \(appName)", action: nil, keyEquivalent: "")
        appHeader.isEnabled = false
        menu.addItem(appHeader)

        let shortcutsItem = NSMenuItem(title: "Manage Shortcuts…", action: #selector(openShortcutsWindow), keyEquivalent: "m")
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)

        let excludeItem = NSMenuItem(
            title: prefs.isAppExcluded(bid) ? "Include This App" : "Exclude This App",
            action: #selector(toggleExclude), keyEquivalent: "")
        excludeItem.target = self
        excludeItem.representedObject = bid
        menu.addItem(excludeItem)

        menu.addItem(.separator())

        // Appearance submenu
        let appearance = NSMenu()
        for opacity in [0.3, 0.5, 0.7, 0.9, 1.0] {
            let item = NSMenuItem(title: "\(Int(opacity * 100))%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = opacity
            item.state = abs(prefs.opacity - opacity) < 0.01 ? .on : .off
            appearance.addItem(item)
        }
        let appearanceItem = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        menu.setSubmenu(appearance, for: appearanceItem)
        menu.addItem(appearanceItem)

        let speedMenu = NSMenu()
        for (label, speed) in [("Slow", 25.0), ("Normal", 45.0), ("Fast", 90.0)] {
            let item = NSMenuItem(title: label, action: #selector(setSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = speed
            item.state = abs(prefs.speed - speed) < 0.01 ? .on : .off
            speedMenu.addItem(item)
        }
        let speedItem = NSMenuItem(title: "Scroll Speed", action: nil, keyEquivalent: "")
        menu.setSubmenu(speedMenu, for: speedItem)
        menu.addItem(speedItem)

        let fadeItem = NSMenuItem(
            title: prefs.fadeOnMouseProximity ? "✓ Fade on Mouse Hover" : "Fade on Mouse Hover",
            action: #selector(toggleFade), keyEquivalent: "")
        fadeItem.target = self
        menu.addItem(fadeItem)

        let colorsItem = NSMenuItem(title: "Customize Colors…", action: #selector(openColorsWindow), keyEquivalent: "")
        colorsItem.target = self
        menu.addItem(colorsItem)

        menu.addItem(.separator())

        let resetItem = NSMenuItem(title: "Reset Learned Shortcuts (This App)", action: #selector(resetLearnedForApp), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        let resetAllItem = NSMenuItem(title: "Reset All Learned Shortcuts", action: #selector(resetAllLearned), keyEquivalent: "")
        resetAllItem.target = self
        menu.addItem(resetAllItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About KeyTicker", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleVisible() {
        tickerController.toggle()
        rebuildMenu()
    }

    @objc private func toggleExclude() {
        guard let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        prefs.setAppExcluded(bid, excluded: !prefs.isAppExcluded(bid))
        refreshCurrent()
        rebuildMenu()
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        guard let opacity = sender.representedObject as? Double else { return }
        prefs.opacity = opacity
        tickerController.applyAppearance()
        rebuildMenu()
    }

    @objc private func setSpeed(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? Double else { return }
        prefs.speed = speed
        tickerController.applyAppearance()
        rebuildMenu()
    }

    @objc private func toggleFade() {
        prefs.fadeOnMouseProximity.toggle()
        tickerController.applyAppearance()
        rebuildMenu()
    }

    @objc private func resetLearnedForApp() {
        guard let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        prefs.resetLearned(bundleID: bid)
        refreshCurrent()
    }

    @objc private func resetAllLearned() {
        prefs.resetAllLearned()
        refreshCurrent()
    }

    @objc private func openShortcutsWindow() {
        if shortcutsWindow == nil {
            let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "_global"
            let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "—"
            let view = ShortcutsManagerView(bundleID: bid, appName: name, store: store, prefs: prefs) { [weak self] in
                self?.refreshCurrent()
            }
            let host = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: host)
            win.title = "KeyTicker — Shortcuts"
            win.setContentSize(NSSize(width: 520, height: 480))
            win.styleMask = [.titled, .closable, .resizable]
            win.isReleasedWhenClosed = false
            shortcutsWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        shortcutsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openColorsWindow() {
        if colorsWindow == nil {
            let view = ColorsView(prefs: prefs) { [weak self] in
                self?.tickerController.applyAppearance()
                self?.refreshCurrent()
            }
            let host = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: host)
            win.title = "KeyTicker — Colors"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            colorsWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        colorsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAbout() {
        let alert = NSAlert()
        alert.messageText = "KeyTicker"
        alert.informativeText = "A discreet scrolling ticker that teaches you keyboard shortcuts for whichever app you're using.\n\nMark shortcuts as learned to remove them from the ticker. Move your mouse near the ticker to fade it out.\n\nMIT licensed. Contributions welcome."
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refreshCurrent() {
        if let app = NSWorkspace.shared.frontmostApplication {
            handleAppChange(bundleID: app.bundleIdentifier, name: app.localizedName ?? "")
        }
    }
}
