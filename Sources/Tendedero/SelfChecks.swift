#if LINESHELF_CHECKS
import AppKit
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { precondition(a == b, "Not equal: \(a) / \(b)", file: file, line: line) }
func XCTAssertEqual(_ a: [URL], _ b: [URL], file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(a.map { $0.resolvingSymlinksInPath().path }, b.map { $0.resolvingSymlinksInPath().path }, file: file, line: line)
}
func XCTAssertNotEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a != b) }
func XCTAssertTrue(_ value: Bool) { precondition(value) }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }
func XCTAssertNil<T>(_ value: T?) { precondition(value == nil) }
func XCTAssertNotNil<T>(_ value: T?) { precondition(value != nil) }
func XCTUnwrap<T>(_ value: T?) throws -> T { precondition(value != nil); return value! }


@MainActor
final class DownloadTests {
    var folder: URL!
    func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }
    @discardableResult func file(_ name: String, _ data: String = "hello") throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data(data.utf8).write(to: url)
        return url
    }
    let zero = Date(timeIntervalSince1970: 1000)

    func testBaselineAndOldTimestampArrival() throws {
        try file("historical.pdf")
        let tracker = DownloadTracker(folder: folder)
        XCTAssertEqual(try tracker.scan(at: zero), [])
        let url = try file("airdrop.txt")
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: url.path)
        XCTAssertEqual(try tracker.scan(at: zero + 1), [])
        XCTAssertEqual(try tracker.scan(at: zero + 4), [url])
        XCTAssertEqual(try tracker.scan(at: zero + 10), [])
    }

    func testBrowserFinalRenameAndHiddenTemps() throws {
        let tracker = DownloadTracker(folder: folder)
        _ = try tracker.scan(at: zero)
        let temp = try file("report.zip.crdownload")
        try file(".airdrop-temp")
        XCTAssertEqual(try tracker.scan(at: zero + 1), [])
        XCTAssertEqual(try tracker.scan(at: zero + 8), [])
        let final = folder.appendingPathComponent("report.zip")
        try FileManager.default.moveItem(at: temp, to: final)
        XCTAssertEqual(try tracker.scan(at: zero + 9), [])
        XCTAssertEqual(try tracker.scan(at: zero + 12), [final])
    }

    func testGrowingFileRestartsSettlingAndDeletedPendingIsIgnored() throws {
        let tracker = DownloadTracker(folder: folder)
        _ = try tracker.scan(at: zero)
        let url = try file("attachment.docx")
        _ = try tracker.scan(at: zero + 1)
        try Data("more bytes".utf8).write(to: url)
        XCTAssertEqual(try tracker.scan(at: zero + 3), [])
        XCTAssertEqual(try tracker.scan(at: zero + 4), [])
        XCTAssertEqual(try tracker.scan(at: zero + 6), [url])
        let vanished = try file("vanished.xlsx")
        _ = try tracker.scan(at: zero + 7)
        try FileManager.default.removeItem(at: vanished)
        XCTAssertEqual(try tracker.scan(at: zero + 10), [])
        try FileManager.default.removeItem(at: url)
        _ = try tracker.scan(at: zero + 11)
        try file("attachment.docx")
        _ = try tracker.scan(at: zero + 12)
        XCTAssertEqual(try tracker.scan(at: zero + 15), [url])
    }

    func testAriaSidecarAndFolderContents() throws {
        let tracker = DownloadTracker(folder: folder)
        _ = try tracker.scan(at: zero)
        let zip = try file("download.zip")
        let sidecar = try file("download.zip.aria2")
        XCTAssertEqual(try tracker.scan(at: zero + 1), [])
        XCTAssertEqual(try tracker.scan(at: zero + 5), [])
        try FileManager.default.removeItem(at: sidecar)
        _ = try tracker.scan(at: zero + 6)
        XCTAssertEqual(try tracker.scan(at: zero + 9), [zip])
        let dir = folder.appendingPathComponent("AirDrop folder")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let child = dir.appendingPathComponent("file.txt")
        try Data("one".utf8).write(to: child)
        _ = try tracker.scan(at: zero + 10)
        try Data("larger content".utf8).write(to: child)
        XCTAssertEqual(try tracker.scan(at: zero + 12), [])
        XCTAssertEqual(try tracker.scan(at: zero + 13), [])
        XCTAssertEqual(try tracker.scan(at: zero + 15), [dir])
    }

    func testManualDropCopiesAndKeepsOriginal() throws {
        let original = try file("manual.txt")
        let received = try FileShelf.receive(original)
        defer { try? FileManager.default.removeItem(at: received.deletingLastPathComponent()) }
        XCTAssertNotEqual(original, received)
        XCTAssertEqual(try Data(contentsOf: original), try Data(contentsOf: received))
        XCTAssertTrue(FileShelf.owns(received))
        XCTAssertEqual(try FileShelf.receive(received), received)
    }

    @MainActor func testGenericFilesHangOnceAndTakeDownPreservesDownload() throws {
        let original = try file("document.pdf")
        let line = Line()
        line.maxItems = 100
        let id = try XCTUnwrap(line.hang(original, quietly: true))
        XCTAssertNil(line.hang(original, quietly: true))
        XCTAssertFalse(line.isInInbox(id))
        XCTAssertNotNil(makeThumbnail(original))
        line.discard(id, quietly: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(line.items.first(where: { $0.id == id })?.falling == true)
    }
}

@MainActor func runLineShelfChecks() throws {
    _ = NSApplication.shared
    let checks = DownloadTests()
    let cases: [(String, () throws -> Void)] = [
        ("baseline and old timestamp arrival", checks.testBaselineAndOldTimestampArrival),
        ("browser final rename and hidden temporary files", checks.testBrowserFinalRenameAndHiddenTemps),
        ("growing and deleted files", checks.testGrowingFileRestartsSettlingAndDeletedPendingIsIgnored),
        ("aria2 sidecar and folder contents", checks.testAriaSidecarAndFolderContents),
        ("manual drop retains original and copies content", checks.testManualDropCopiesAndKeepsOriginal),
        ("generic file display, deduplication and take-down", checks.testGenericFilesHangOnceAndTakeDownPreservesDownload)
    ]
    for (name, check) in cases {
        try checks.setUpWithError()
        try check()
        try checks.tearDownWithError()
        print("PASS: \(name)")
    }
    print("All 6 checks passed")
}
#endif
