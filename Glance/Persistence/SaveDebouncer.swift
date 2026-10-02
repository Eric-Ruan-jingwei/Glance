import Foundation

@MainActor
final class SaveDebouncer {
    private struct Pending {
        var work: DispatchWorkItem
        var action: () -> Void
    }

    private var pending: [String: Pending] = [:]

    func schedule(id: String, delay: TimeInterval, action: @escaping () -> Void) {
        pending[id]?.work.cancel()
        let work = DispatchWorkItem { [weak self] in
            action()
            self?.pending[id] = nil
        }
        pending[id] = Pending(work: work, action: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func flush() {
        let items = pending
        pending.removeAll()
        for (_, item) in items {
            item.work.cancel()
            item.action()
        }
    }

    func flush(id: String) {
        guard let item = pending.removeValue(forKey: id) else { return }
        item.work.cancel()
        item.action()
    }

    func cancel(id: String) {
        pending[id]?.work.cancel()
        pending[id] = nil
    }
}
