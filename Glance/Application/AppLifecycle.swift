import Foundation

enum AppLifecycle {
    @MainActor
    static func handleTerminate(manager: PanelManager?, environment: AppEnvironment?) {
        environment?.debouncer.flush()
        manager?.shutdown()
        try? environment?.repository.save()
    }
}
