import SwiftUI

struct ShortcutsManagerView: View {
    let bundleID: String
    let appName: String
    let store: ShortcutStore
    let prefs: Preferences
    let onChange: () -> Void

    @State private var excluded: Bool
    @State private var learnedIDs: Set<String> = []
    @State private var refreshToken: Int = 0

    init(bundleID: String, appName: String, store: ShortcutStore, prefs: Preferences, onChange: @escaping () -> Void) {
        self.bundleID = bundleID
        self.appName = appName
        self.store = store
        self.prefs = prefs
        self.onChange = onChange
        _excluded = State(initialValue: prefs.isAppExcluded(bundleID))
    }

    var shortcuts: [Shortcut] { store.shortcuts(for: bundleID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(appName).font(.title2).bold()
                    Text(bundleID).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Hide ticker for this app", isOn: $excluded)
                    .toggleStyle(.switch)
                    .onChange(of: excluded) { v in
                        prefs.setAppExcluded(bundleID, excluded: v)
                        onChange()
                    }
            }

            if !store.hasCustomSet(for: bundleID) {
                Text("No shortcut set for this app yet — showing macOS globals only. Contribute one at github.com/cfranci/keyticker.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(8).background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
            }

            HStack {
                Text("Check shortcuts you’ve learned to remove them from the ticker.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Reset") {
                    prefs.resetLearned(bundleID: bundleID)
                    learnedIDs = []
                    refreshToken += 1
                    onChange()
                }
            }

            List {
                ForEach(shortcuts) { s in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { learnedIDs.contains(s.id) || prefs.isLearned(bundleID: bundleID, shortcutID: s.id) },
                            set: { v in
                                prefs.setLearned(bundleID: bundleID, shortcutID: s.id, learned: v)
                                if v { learnedIDs.insert(s.id) } else { learnedIDs.remove(s.id) }
                                onChange()
                            }
                        )) {
                            HStack(spacing: 12) {
                                Text(s.keys)
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                                    .frame(minWidth: 140, alignment: .leading)
                                Text(s.action)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .id(refreshToken)
        }
        .padding(16)
        .frame(minWidth: 500, minHeight: 420)
        .onAppear {
            // seed learnedIDs from prefs
            for s in shortcuts where prefs.isLearned(bundleID: bundleID, shortcutID: s.id) {
                learnedIDs.insert(s.id)
            }
        }
    }
}
