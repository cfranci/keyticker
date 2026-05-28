import SwiftUI
import AppKit

struct ColorsView: View {
    let prefs: Preferences
    let onChange: () -> Void

    @State private var bg: Color
    @State private var app: Color
    @State private var shortcut: Color

    init(prefs: Preferences, onChange: @escaping () -> Void) {
        self.prefs = prefs
        self.onChange = onChange
        _bg = State(initialValue: Color(nsColor: prefs.bgColor))
        _app = State(initialValue: Color(nsColor: prefs.appLabelColor))
        _shortcut = State(initialValue: Color(nsColor: prefs.shortcutColor))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Customize Colors").font(.title2).bold()
            Text("The background swatch's opacity controls how transparent the ticker bar is.")
                .font(.callout).foregroundStyle(.secondary)

            row("Background", binding: $bg) { c in
                prefs.bgColor = NSColor(c)
                onChange()
            }
            row("App label", binding: $app) { c in
                prefs.appLabelColor = NSColor(c)
                onChange()
            }
            row("Shortcut text", binding: $shortcut) { c in
                prefs.shortcutColor = NSColor(c)
                onChange()
            }

            HStack {
                Spacer()
                Button("Reset to defaults") {
                    prefs.resetColors()
                    bg = Color(nsColor: prefs.bgColor)
                    app = Color(nsColor: prefs.appLabelColor)
                    shortcut = Color(nsColor: prefs.shortcutColor)
                    onChange()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealHeight: 260)
    }

    @ViewBuilder
    private func row(_ label: String, binding: Binding<Color>, onCommit: @escaping (Color) -> Void) -> some View {
        HStack(spacing: 12) {
            ColorPicker(selection: binding, supportsOpacity: true) {
                Text(label).frame(width: 110, alignment: .leading)
            }
            .onChange(of: binding.wrappedValue) { v in onCommit(v) }
        }
    }
}
