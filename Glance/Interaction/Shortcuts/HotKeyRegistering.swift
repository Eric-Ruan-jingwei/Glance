import Foundation

protocol HotKeyRegistering: AnyObject {
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) throws
    func unregister(id: UInt32)
}

final class FakeHotKeyRegistrar: HotKeyRegistering {
    private(set) var registered: [UInt32: (keyCode: UInt32, modifiers: UInt32)] = [:]
    var failingIDs: Set<UInt32> = []
    var failNextRegister = false
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) throws {
        registerCount += 1
        if failNextRegister || failingIDs.contains(id) {
            failNextRegister = false
            throw ShortcutError.registrationFailed
        }
        registered[id] = (keyCode, modifiers)
    }

    func unregister(id: UInt32) {
        unregisterCount += 1
        registered.removeValue(forKey: id)
    }
}
