import Foundation

enum AppLifecycle {
    @MainActor
    static func handleTerminate(manager: PanelManager?, environment: AppEnvironment?) {
        environment?.debouncer.flush()
        manager?.shutdown()
        do {
            try environment?.repository.save()
        } catch {
            NSLog("Glance persistence: failed to flush metadata on terminate: %@", error.localizedDescription)
        }
    }
}
