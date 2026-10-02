import Foundation

enum PayloadStoreError: LocalizedError {
    case directoryCreationFailed(URL, Error)
    case writeFailed(URL, Error)
    case deleteFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let url, let error):
            return "无法创建面板内容目录 \(url.path): \(error.localizedDescription)"
        case .writeFailed(let url, let error):
            return "无法写入 \(url.path): \(error.localizedDescription)"
        case .deleteFailed(let url, let error):
            return "无法删除 \(url.path): \(error.localizedDescription)"
        }
    }
}

enum PayloadLoadError: LocalizedError {
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            return "无法读取已有内容文件 \(url.path)，已保留原文件。"
        }
    }
}

final class PayloadStore {
    let applicationSupportRoot: URL
    let databaseDirectory: URL
    let panelsRoot: URL

    init(applicationSupportRoot: URL) throws {
        self.applicationSupportRoot = applicationSupportRoot
        self.databaseDirectory = applicationSupportRoot.appendingPathComponent("Database", isDirectory: true)
        self.panelsRoot = applicationSupportRoot.appendingPathComponent("Panels", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: panelsRoot, withIntermediateDirectories: true)
        } catch {
            throw PayloadStoreError.directoryCreationFailed(applicationSupportRoot, error)
        }
    }

    func directory(for id: UUID) throws -> URL {
        let dir = panelsRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw PayloadStoreError.directoryCreationFailed(dir, error)
        }
        return dir
    }

    func relativePath(for id: UUID) -> String {
        "Panels/\(id.uuidString)"
    }

    func delete(id: UUID) {
        let dir = panelsRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            NSLog("Glance persistence: %@", PayloadStoreError.deleteFailed(dir, error).localizedDescription)
        }
    }

    var metadataURL: URL {
        databaseDirectory.appendingPathComponent("panels.json")
    }
}
