import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status == .enabled { return }
            try SMAppService.mainApp.register()
        } else {
            if SMAppService.mainApp.status == .notFound { return }
            if SMAppService.mainApp.status == .notRegistered { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
