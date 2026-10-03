import XCTest
import AppKit

#if canImport(GlanceCore)
@testable import GlanceCore
#else
@testable import Glance
#endif

final class ScriptedSummaryLoader: PanelSummaryLoading, @unchecked Sendable {
    struct Step {
        var delayNanoseconds: UInt64
        var summaries: [PanelSummary]
        var gate: LoadGate?
        var started: LoadGate?
    }

    private let steps: [Step]
    private let counter = StepCounter()

    init(steps: [Step]) {
        self.steps = steps
    }

    func loadSummaries(inputs: [PanelSummaryInput]) async -> [PanelSummary] {
        let stepIndex = await counter.next()
        let step = steps[min(stepIndex, steps.count - 1)]
        if let started = step.started {
            await started.open()
        }
        if let gate = step.gate {
            await gate.wait()
        }
        if step.delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: step.delayNanoseconds)
        }
        return step.summaries
    }
}

actor StepCounter {
    private var index = 0

    func next() -> Int {
        defer { index += 1 }
        return index
    }
}

actor LoadGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if opened { return }
        await withCheckedContinuation { continuation in
            if opened {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }

    func open() {
        opened = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

@MainActor
final class PanelSummaryLoadingTests: XCTestCase {
    func testAsyncLoadAppliesSummariesInInputOrder() async {
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()
        let loader = ScriptedSummaryLoader(steps: [
            .init(
                delayNanoseconds: 20_000_000,
                summaries: [
                    summary(id: firstID, title: "One"),
                    summary(id: secondID, title: "Two"),
                    summary(id: thirdID, title: "Three")
                ]
            )
        ])
        let model = PanelLibraryModel()
        model.summaryLoader = loader
        model.loadSummaryInputs = {
            [firstID, secondID, thirdID].map { dummyInput(id: $0) }
        }
        model.reload()
        await waitUntil(timeout: 1) { model.summaries.map(\.title) == ["One", "Two", "Three"] }
        XCTAssertEqual(model.summaries.map(\.id), [firstID, secondID, thirdID])
    }

    func testBoundedLoaderPreservesInputOrder() async throws {
        let names = ["Alpha", "Beta", "Gamma"]
        var directories: [URL] = []
        defer {
            for directory in directories {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        var inputs: [PanelSummaryInput] = []
        for name in names {
            let directory = uniqueTempDirectory("GlanceSummaryLoad")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            directories.append(directory)
            try TextPayloadFile.writePlainText(name, to: directory)
            inputs.append(dummyInput(id: UUID(), directory: directory))
        }
        let summaries = await PanelSummaryLoader(maxConcurrent: 2).loadSummaries(inputs: inputs)
        XCTAssertEqual(summaries.map(\.id), inputs.map(\.id))
        XCTAssertEqual(summaries.map(\.title), names)
        XCTAssertTrue(summaries.allSatisfy { !$0.isUnreadable })
    }

    func testStaleGenerationDoesNotOverwriteNewerResult() async {
        let first = summary(title: "Old")
        let second = summary(title: "New")
        let staleGate = LoadGate()
        let staleStarted = LoadGate()
        let loader = ScriptedSummaryLoader(steps: [
            .init(delayNanoseconds: 0, summaries: [first], gate: staleGate, started: staleStarted),
            .init(delayNanoseconds: 0, summaries: [second])
        ])
        let model = PanelLibraryModel()
        model.summaryLoader = loader
        model.loadSummaryInputs = { [dummyInput(id: first.id)] }
        model.reload()
        await staleStarted.wait()
        model.loadSummaryInputs = { [dummyInput(id: second.id)] }
        model.reload()
        await waitUntil(timeout: 1) { model.summaries.map(\.title) == ["New"] }
        await staleGate.open()
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(model.summaries.map(\.title), ["New"])
        XCTAssertEqual(model.summaries.map(\.id), [second.id])
    }

    func testCancelDiscardsOutstandingSummaryLoad() async {
        let kept = summary(title: "Kept")
        let delayed = summary(title: "Delayed")
        let gate = LoadGate()
        let model = PanelLibraryModel()
        model.loadSummaries = { [kept] }
        model.reload()
        XCTAssertEqual(model.summaries.map(\.title), ["Kept"])

        model.summaryLoader = ScriptedSummaryLoader(steps: [
            .init(delayNanoseconds: 0, summaries: [delayed], gate: gate)
        ])
        model.loadSummaryInputs = { [dummyInput(id: delayed.id)] }
        model.reload()
        model.cancelSummaryLoading()
        await gate.open()
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertEqual(model.summaries.map(\.title), ["Kept"])
        XCTAssertEqual(model.summaries.map(\.id), [kept.id])
    }

    func testApplyLoadedSummariesIgnoresStaleGeneration() {
        let model = PanelLibraryModel()
        let current = summary(title: "Current")
        let stale = summary(title: "Stale")
        let generation = model.beginSummaryRequest()
        model.applyLoadedSummaries([current], generation: generation)
        model.applyLoadedSummaries([stale], generation: generation - 1)
        XCTAssertEqual(model.summaries.map(\.title), ["Current"])
    }

    func testUnreadablePayloadDoesNotFailWholeLoad() async throws {
        var directories: [URL] = []
        defer {
            for directory in directories {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        let readableA = uniqueTempDirectory("GlanceReadableA")
        let corrupt = uniqueTempDirectory("GlanceCorruptImage")
        let readableC = uniqueTempDirectory("GlanceReadableC")
        directories = [readableA, corrupt, readableC]
        try FileManager.default.createDirectory(at: readableA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: corrupt, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: readableC, withIntermediateDirectories: true)
        try TextPayloadFile.writePlainText("Alpha note", to: readableA)
        try Data("not-an-image".utf8).write(to: corrupt.appendingPathComponent("image.png"))
        try TextPayloadFile.writePlainText("Gamma note", to: readableC)

        let inputs = [
            dummyInput(id: UUID(), kind: PanelKind.text, directory: readableA),
            dummyInput(id: UUID(), kind: PanelKind.image, directory: corrupt),
            dummyInput(id: UUID(), kind: PanelKind.text, directory: readableC)
        ]
        let summaries = await PanelSummaryLoader(maxConcurrent: 3).loadSummaries(inputs: inputs)
        XCTAssertEqual(summaries.count, 3)
        XCTAssertEqual(summaries[0].title, "Alpha note")
        XCTAssertFalse(summaries[0].isUnreadable)
        XCTAssertEqual(summaries[1].title, PanelSummaryFallback.unreadable)
        XCTAssertTrue(summaries[1].isUnreadable)
        XCTAssertEqual(summaries[2].title, "Gamma note")
        XCTAssertFalse(summaries[2].isUnreadable)
        XCTAssertEqual(try Data(contentsOf: corrupt.appendingPathComponent("image.png")), Data("not-an-image".utf8))
    }

    func testSelectionReconcileAfterAsyncApply() async {
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        let a = summary(id: idA, title: "A")
        let b = summary(id: idB, title: "B")
        let c = summary(id: idC, title: "C")
        let model = PanelLibraryModel()
        model.loadSummaries = { [a, b, c] }
        model.reload()
        model.selectedPanelIDs = [idA, idB]
        XCTAssertEqual(model.selectedPanelIDs, [idA, idB])

        model.summaryLoader = ScriptedSummaryLoader(steps: [
            .init(delayNanoseconds: 0, summaries: [b, c])
        ])
        model.loadSummaryInputs = { [dummyInput(id: idB), dummyInput(id: idC)] }
        model.reload()
        await waitUntil(timeout: 1) { model.summaries.map(\.id) == [idB, idC] }
        XCTAssertEqual(model.selectedPanelIDs, [idB])
    }
}

final class ImageMetadataProbeTests: XCTestCase {
    func testImageMetadataProbeReadsPixelSize() throws {
        let directory = uniqueTempDirectory("GlanceImageMeta")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("image.png")
        let png = GlanceTestPNG.data(width: 64, height: 48)
        XCTAssertFalse(png.isEmpty)
        try png.write(to: url)
        let size = try XCTUnwrap(ImagePixelSize.read(fromFile: url))
        XCTAssertEqual(size.width, 64)
        XCTAssertEqual(size.height, 48)
        let summary = PanelSummaryBuilder.summarize(
            input: dummyInput(kind: PanelKind.image, directory: directory)
        )
        XCTAssertEqual(summary.subtitle, "64 × 48")
        XCTAssertFalse(summary.isUnreadable)
    }

    func testCorruptImageProbeDoesNotRewriteBytes() throws {
        let directory = uniqueTempDirectory("GlanceImageCorrupt")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("image.png")
        let original = Data("corrupt-png-bytes".utf8)
        try original.write(to: url)
        XCTAssertNil(ImagePixelSize.read(fromFile: url))
        let summary = PanelSummaryBuilder.summarize(
            input: dummyInput(kind: PanelKind.image, directory: directory)
        )
        XCTAssertTrue(summary.isUnreadable)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}

@MainActor
final class PersistenceDiagnosticTests: XCTestCase {
    func testMapsKnownLoadOutcomes() {
        XCTAssertEqual(
            PersistenceDiagnostic.from(outcome: .recoveredFromBackup),
            .recoveredFromBackup
        )
        XCTAssertEqual(
            PersistenceDiagnostic.from(outcome: .quarantinedCorruptAndEmpty),
            .quarantinedCorruptMetadata
        )
        XCTAssertEqual(
            PersistenceDiagnostic.from(outcome: .unsupportedFutureSchema(6)),
            .unsupportedFutureSchema(6)
        )
        XCTAssertNil(PersistenceDiagnostic.from(outcome: .missing))
        XCTAssertNil(PersistenceDiagnostic.from(outcome: .loaded(migratedFromLegacy: false)))
        XCTAssertNil(PersistenceDiagnostic.from(outcome: .loaded(migratedFromLegacy: true)))
    }

    func testBackupRecoveryCopyDoesNotClaimPayloadIntegrity() {
        let text = PersistenceDiagnostic.recoveredFromBackup.alertInformative
        XCTAssertTrue(text.contains("从本地备份恢复面板信息"))
        XCTAssertTrue(text.contains("建议确认面板内容是否完整"))
    }

    func testCorruptQuarantineCopyPreservesFileAndEmptyList() {
        let text = PersistenceDiagnostic.quarantinedCorruptMetadata.alertInformative
        XCTAssertTrue(text.contains("panels.corrupted-"))
        XCTAssertTrue(text.contains("没有删除该文件"))
        XCTAssertTrue(text.contains("当前面板列表可能为空"))
    }

    func testFutureSchemaCopyDoesNotOverwrite() {
        let text = PersistenceDiagnostic.unsupportedFutureSchema(6).alertInformative
        XCTAssertTrue(text.contains("不会修改或降级"))
        XCTAssertTrue(text.contains("也不会覆盖"))
    }

    func testBackupRecoveryProducesUserFacingDiagnostic() throws {
        try withIsolatedRepository { _, metadataURL in
            let record = GlanceTestFixtures.sampleRecord()
            let first = try PanelRepository(fileURL: metadataURL)
            try first.insert(record)
            try Data("CORRUPT".utf8).write(to: metadataURL)
            let recovered = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(recovered.lastLoadOutcome, .recoveredFromBackup)
            XCTAssertEqual(PersistenceDiagnostic.from(outcome: recovered.lastLoadOutcome), .recoveredFromBackup)
            XCTAssertEqual(try recovered.all().map(\.id), [record.id])
        }
    }

    func testCorruptMetadataProducesQuarantineDiagnostic() throws {
        try withIsolatedRepository { directory, metadataURL in
            try Data("{ not-json".utf8).write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .quarantinedCorruptAndEmpty)
            XCTAssertEqual(
                PersistenceDiagnostic.from(outcome: repository.lastLoadOutcome),
                .quarantinedCorruptMetadata
            )
            let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            XCTAssertTrue(leftovers.contains { $0.hasPrefix("panels.corrupted-") && $0.hasSuffix(".json") })
        }
    }

    func testFutureSchemaDiagnosticLeavesBytesUnchanged() throws {
        try withIsolatedRepository { _, metadataURL in
            let original = Data(GlanceTestFixtures.futureSchemaJSON.utf8)
            try original.write(to: metadataURL)
            let repository = try PanelRepository(fileURL: metadataURL)
            XCTAssertEqual(repository.lastLoadOutcome, .unsupportedFutureSchema(6))
            XCTAssertEqual(
                PersistenceDiagnostic.from(outcome: repository.lastLoadOutcome),
                .unsupportedFutureSchema(6)
            )
            XCTAssertEqual(try Data(contentsOf: metadataURL), original)
            try repository.save()
            XCTAssertEqual(try Data(contentsOf: metadataURL), original)
        }
    }

    @MainActor
    func testStatusMenuShowsDiagnosticOnlyWhenPresent() {
        let hidden = populatedMenuTitles(diagnostic: nil)
        XCTAssertFalse(hidden.contains { $0.contains("数据恢复提示") })

        let shown = populatedMenuTitles(diagnostic: .recoveredFromBackup)
        XCTAssertTrue(shown.contains("⚠ 数据恢复提示…"))
        XCTAssertEqual(shown.last, "退出")
    }
}

@MainActor
final class TestIsolationTests: XCTestCase {
    func testTwoTempRootsDoNotShareWrites() throws {
        try withIsolatedRepository { _, metadataA in
            try withIsolatedRepository { _, metadataB in
                let repoA = try PanelRepository(fileURL: metadataA)
                let repoB = try PanelRepository(fileURL: metadataB)
                let record = GlanceTestFixtures.sampleRecord()
                try repoA.insert(record)
                XCTAssertEqual(try repoA.all().map(\.id), [record.id])
                XCTAssertTrue(try repoB.all().isEmpty)
                XCTAssertNotEqual(metadataA.path, metadataB.path)
            }
        }
    }
}

private func dummyInput(
    id: UUID = UUID(),
    kind: String = PanelKind.text,
    directory: URL = FileManager.default.temporaryDirectory
) -> PanelSummaryInput {
    PanelSummaryInput(
        id: id,
        kindIdentifier: kind,
        customTitle: nil,
        workspaceID: WorkspaceRecord.defaultID,
        tags: [],
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 2),
        isLocked: false,
        isPassThrough: false,
        isPinned: false,
        isHidden: false,
        payloadDirectory: directory
    )
}

private func summary(id: UUID = UUID(), title: String) -> PanelSummary {
    PanelSummary(
        id: id,
        kindIdentifier: PanelKind.text,
        title: title,
        subtitle: nil,
        preview: "",
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 2),
        isLocked: false,
        isPassThrough: false,
        isPinned: false,
        isHidden: false,
        isUnreadable: false
    )
}

private func uniqueTempDirectory(_ prefix: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
}

private func withIsolatedRepository(_ body: (URL, URL) throws -> Void) throws {
    let directory = uniqueTempDirectory("GlanceHardeningRepo")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory, directory.appendingPathComponent("panels.json"))
}

@MainActor
private func waitUntil(timeout: TimeInterval, _ condition: @escaping () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTAssertTrue(condition(), "timed out waiting for condition")
}

@MainActor
private func populatedMenuTitles(diagnostic: PersistenceDiagnostic?) -> [String] {
    let menu = NSMenu()
    StatusMenuBuilder.populate(
        menu,
        allHidden: false,
        onQuickCapture: {},
        onManagePanels: {},
        onNewText: {},
        onNewMarkdown: {},
        onNewTodo: {},
        onNewImage: {},
        onToggleVisibility: {},
        onSettings: {},
        onQuit: {},
        diagnostic: diagnostic
    )
    return menu.items.map(\.title)
}
