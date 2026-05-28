import Foundation

struct Shortcut: Codable, Identifiable, Hashable {
    let keys: String
    let action: String
    var id: String { "\(keys)|\(action)" }
}

struct ShortcutSet: Codable {
    let bundleID: String
    let appName: String
    let shortcuts: [Shortcut]
}

final class ShortcutStore {
    private(set) var sets: [String: ShortcutSet] = [:]
    private(set) var globalShortcuts: [Shortcut] = []

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.module.url(forResource: "shortcuts", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[KeyTicker] shortcuts.json not found in bundle")
            return
        }
        do {
            let decoded = try JSONDecoder().decode([ShortcutSet].self, from: data)
            for s in decoded {
                sets[s.bundleID] = s
                if s.bundleID == "_global" {
                    globalShortcuts = s.shortcuts
                }
            }
        } catch {
            print("[KeyTicker] failed to decode shortcuts.json: \(error)")
        }
    }

    /// Returns shortcuts for an app, plus globals if a per-app set exists.
    /// If no per-app set, returns globals only.
    func shortcuts(for bundleID: String) -> [Shortcut] {
        if let set = sets[bundleID] {
            return set.shortcuts + globalShortcuts
        }
        return globalShortcuts
    }

    /// Just the app-specific shortcuts (no globals).
    func appSpecificShortcuts(for bundleID: String) -> [Shortcut] {
        sets[bundleID]?.shortcuts ?? []
    }

    func appName(for bundleID: String) -> String? {
        sets[bundleID]?.appName
    }

    func hasCustomSet(for bundleID: String) -> Bool {
        sets[bundleID] != nil
    }
}
