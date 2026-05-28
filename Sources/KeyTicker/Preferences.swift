import Foundation

final class Preferences {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let learned = "learnedShortcuts" // [bundleID: [shortcutID]]
        static let excluded = "excludedApps"     // [bundleID]
        static let opacity = "opacity"
        static let speed = "speed"
        static let fade = "fadeOnMouseProximity"
        static let visible = "tickerVisible"
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
}
