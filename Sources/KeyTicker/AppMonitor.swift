import AppKit

final class AppMonitor {
    private let onChange: (String?, String) -> Void
    private var observer: NSObjectProtocol?

    init(onChange: @escaping (String?, String) -> Void) {
        self.onChange = onChange
    }

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.onChange(app.bundleIdentifier, app.localizedName ?? "")
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}
