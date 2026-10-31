import AppKit
import SwiftUI

/// Accepts both Finder-style file URLs and files supplied lazily by chat apps.
final class FileDropView: NSView {
    var onFiles: ([URL]) -> Void = { _ in }
    var onFailure: (Error) -> Void = { _ in }
    var onHover: (Bool) -> Void = { _ in }
    private let receiverQueue = OperationQueue()

    init(rootView: LineView) {
        super.init(frame: .zero)
        let content = NSHostingView(rootView: rootView)
        content.sizingOptions = []
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        receiverQueue.maxConcurrentOperationCount = 1
    }
    @MainActor required dynamic init?(coder: NSCoder) { fatalError() }

    static func accepts(_ pb: NSPasteboard) -> Bool {
        pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ||
            pb.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !GrabView.isDragging, Self.accepts(sender.draggingPasteboard) else { return [] }
        onHover(true)
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { onHover(false) }
    override func draggingEnded(_ sender: NSDraggingInfo) { onHover(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !GrabView.isDragging && Self.accepts(sender.draggingPasteboard)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onHover(false)
        log.notice("Received incoming file drop")
        let pb = sender.draggingPasteboard
        // Prefer real files if an app supplies both representations.
        let urls = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? [])
            .filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
        if !urls.isEmpty { onFiles(urls); return true }
        guard let receivers = pb.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
              !receivers.isEmpty else { return false }
        do {
            // One destination per drop avoids collisions and retains received files.
            let destination = FileShelf.folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: receiverQueue) { [weak self] url, error in
                    DispatchQueue.main.async {
                        if let error { self?.onFailure(error) }
                        else { self?.onFiles([url]) }
                    }
                }
            }
            return true
        } catch { onFailure(error); return false }
    }
}

enum FileShelf {
    static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("LineShelf/DroppedFiles", isDirectory: true)

    static func owns(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(folder.standardizedFileURL.path + "/")
    }

    /// Incoming drags are copied; the source app retains its original.
    static func receive(_ url: URL) throws -> URL {
        if owns(url) { return url }
        let destination = folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let target = destination.appendingPathComponent(url.lastPathComponent)
        do { try FileManager.default.copyItem(at: url, to: target) }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        return target
    }
}
