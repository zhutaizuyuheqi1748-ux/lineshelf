import Foundation

/// A separate inlet: never changes screenshot settings or moves downloads.
final class DownloadWatcher {
    static var folder: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }
    static var isEnabled: Bool {
        get { !UserDefaults.standard.bool(forKey: "downloadsOff") }
        set { UserDefaults.standard.set(!newValue, forKey: "downloadsOff") }
    }
    private let queue = DispatchQueue(label: "local.lineshelf.downloads", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var generation = UUID()
    private let onNew: (URL) -> Void
    private let onChange: () -> Void
    private let onError: (String?) -> Void

    init(onNew: @escaping (URL) -> Void, onChange: @escaping () -> Void,
         onError: @escaping (String?) -> Void) {
        self.onNew = onNew
        self.onChange = onChange
        self.onError = onError
    }

    // Lifecycle and callbacks belong to the main queue. Scans are serial off it.
    func start() {
        stop()
        let token = generation
        let tracker = DownloadTracker(folder: Self.folder)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.5)
        timer.setEventHandler { [weak self] in
            do {
                let urls = try tracker.scan(at: Date())
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.onError(nil)
                    urls.forEach(self.onNew)
                    self.onChange()
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.onError(error.localizedDescription)
                }
            }
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        generation = UUID()
        timer?.cancel()
        timer = nil
    }
}

/// Testable directory reconciliation. The first successful scan is a baseline;
/// dates from the sending device do not determine whether an arrival is new.
final class DownloadTracker {
    let folder: URL
    private var known: [String: UInt64]?
    private var pending: [String: (stamp: String, since: Date)] = [:]
    private let settleTime: TimeInterval

    init(folder: URL, settleTime: TimeInterval = 3) {
        self.folder = folder
        self.settleTime = settleTime
    }

    static func isTemporary(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name.hasPrefix(".") || name.hasPrefix("~$") ||
            ["crdownload", "download", "part", "partial", "tmp", "temp", "aria2", "filepart", "!qb"].contains(url.pathExtension.lowercased())
    }

    func scan(at now: Date) throws -> [URL] {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                              options: [.skipsHiddenFiles])
        var entries: [String: (url: URL, inode: UInt64, stamp: String)] = [:]
        for url in files where !Self.isTemporary(url) {
            // aria2 writes into the final filename while keeping a sidecar.
            guard !fm.fileExists(atPath: url.path + ".aria2"),
                  !fm.fileExists(atPath: url.path + ".part"),
                  let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let type = attrs[.type] as? FileAttributeType,
                  type == .typeRegular || type == .typeDirectory else { continue }
            let inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
            var stamp = Self.stamp(attrs)
            if known != nil, known?[url.path] != inode, type == .typeDirectory {
                // Only new folders are traversed, never historical downloads.
                // Changes within an AirDrop folder restart its settling period.
                guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles]) else { continue }
                var parts: [String] = []
                var incomplete = false
                for case let child as URL in enumerator {
                    if Self.isTemporary(child) { incomplete = true; break }
                    guard let childAttrs = try? fm.attributesOfItem(atPath: child.path) else {
                        incomplete = true; break
                    }
                    parts.append(child.path + Self.stamp(childAttrs))
                }
                if incomplete { continue }
                stamp += parts.sorted().joined(separator: "|")
            }
            entries[url.path] = (url, inode, stamp)
        }
        guard var base = known else {
            known = entries.mapValues { $0.inode }
            return []
        }
        base = base.filter { entries[$0.key] != nil }
        pending = pending.filter { entries[$0.key] != nil }
        var ready: [URL] = []
        for (path, entry) in entries.sorted(by: { $0.key < $1.key }) where base[path] != entry.inode {
            if let previous = pending[path], previous.stamp == entry.stamp {
                if now.timeIntervalSince(previous.since) >= settleTime {
                    ready.append(entry.url)
                    base[path] = entry.inode
                    pending[path] = nil
                }
            } else {
                pending[path] = (entry.stamp, now)
            }
        }
        known = base
        return ready
    }

    private static func stamp(_ attrs: [FileAttributeKey: Any]) -> String {
        "\(attrs[.systemFileNumber] ?? "")-\(attrs[.size] ?? "")-\((attrs[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0)"
    }
}
