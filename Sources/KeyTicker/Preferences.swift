import AppKit

final class Preferences {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let learned = "learnedShortcuts" // [bundleID: [shortcutID]]
        static let excluded = "excludedApps"     // [bundleID]
        static let opacity = "opacity"
        static let speed = "speed"
        static let fade = "fadeOnMouseProximity"
        static let visible = "tickerVisible"
        static let bgColor = "bgColor"
        static let appLabelColor = "appLabelColor"
        static let shortcutColor = "shortcutColor"
        static let didSeedKnownGlobals = "didSeedKnownGlobals_v1"
    }

    var opacity: Double {
        get { defaults.object(forKey: Keys.opacity) as? Double ?? 0.7 }
        set { defaults.set(newValue, forKey: Keys.opacity) }
    }

    /// Pixels per second.
    var speed: Double {
        get { defaults.object(forKey: Keys.speed) as? Double ?? 35.0 }
        set { defaults.set(newValue, forKey: Keys.speed) }
    }

    var fadeOnMouseProximity: Bool {
        get { defaults.object(forKey: Keys.fade) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.fade) }
    }

    var tickerVisible: Bool {
        get { defaults.object(forKey: Keys.visible) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.visible) }
    }

    private var learnedMap: [String: [String]] {
        get { defaults.dictionary(forKey: Keys.learned) as? [String: [String]] ?? [:] }
        set { defaults.set(newValue, forKey: Keys.learned) }
    }

    private var excludedSet: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.excluded) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.excluded) }
    }

    func isLearned(bundleID: String, shortcutID: String) -> Bool {
        learnedMap[bundleID]?.contains(shortcutID) ?? false
    }

    func setLearned(bundleID: String, shortcutID: String, learned: Bool) {
        var map = learnedMap
        var list = map[bundleID] ?? []
        if learned {
            if !list.contains(shortcutID) { list.append(shortcutID) }
        } else {
            list.removeAll { $0 == shortcutID }
        }
        map[bundleID] = list
        learnedMap = map
    }

    func resetLearned(bundleID: String) {
        var map = learnedMap
        map.removeValue(forKey: bundleID)
        learnedMap = map
    }

    func resetAllLearned() {
        learnedMap = [:]
    }

    func isAppExcluded(_ bundleID: String) -> Bool {
        excludedSet.contains(bundleID)
    }

    func setAppExcluded(_ bundleID: String, excluded: Bool) {
        var set = excludedSet
        if excluded { set.insert(bundleID) } else { set.remove(bundleID) }
        excludedSet = set
    }

    // MARK: - Colors

    var bgColor: NSColor {
        get { color(forKey: Keys.bgColor) ?? NSColor.black.withAlphaComponent(0.6) }
        set { setColor(newValue, forKey: Keys.bgColor) }
    }

    var appLabelColor: NSColor {
        get { color(forKey: Keys.appLabelColor) ?? .systemTeal }
        set { setColor(newValue, forKey: Keys.appLabelColor) }
    }

    var shortcutColor: NSColor {
        get { color(forKey: Keys.shortcutColor) ?? .white }
        set { setColor(newValue, forKey: Keys.shortcutColor) }
    }

    func resetColors() {
        defaults.removeObject(forKey: Keys.bgColor)
        defaults.removeObject(forKey: Keys.appLabelColor)
        defaults.removeObject(forKey: Keys.shortcutColor)
    }

    private func color(forKey key: String) -> NSColor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    private func setColor(_ color: NSColor, forKey key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - One-shot seeding (mark obvious globals as learned for this user)

    /// Mark a set of well-known global shortcuts as already learned, only on first launch.
    /// Idempotent — guarded by a versioned defaults flag.
    func seedKnownGlobalsIfNeeded(_ ids: [String]) {
        guard !defaults.bool(forKey: Keys.didSeedKnownGlobals) else { return }
        for id in ids {
            setLearned(bundleID: "_global", shortcutID: id, learned: true)
        }
        defaults.set(true, forKey: Keys.didSeedKnownGlobals)
    }
}
