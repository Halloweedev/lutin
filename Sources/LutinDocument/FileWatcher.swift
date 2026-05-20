import Foundation
import CoreServices

/// FSEvents-backed watcher for a single file. Coalesces consecutive events
/// within a small debounce window and can suppress its own writes briefly so
/// atomic save+rename doesn't echo back as an external change.
public final class FileWatcher {
    public let fileURL: URL
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "lutin.filewatcher")
    private var suppressionDeadline: Date = .distantPast
    private let lock = NSLock()

    public init(fileURL: URL, onChange: @escaping () -> Void) {
        self.fileURL = fileURL.standardizedFileURL
        self.onChange = onChange
    }

    public func start() throws {
        let dir = fileURL.deletingLastPathComponent().path as CFString
        let paths = [dir] as CFArray
        var context = FSEventStreamContext(version: 0,
                                           info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let flags: UInt32 = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, FileWatcher.callback, &context, paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1, flags) else {
            throw NSError(domain: "FileWatcher", code: -1)
        }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    public func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    public func suppressNextChange(for duration: TimeInterval) {
        lock.lock()
        suppressionDeadline = Date().addingTimeInterval(duration)
        lock.unlock()
    }

    fileprivate func fire(for paths: [String]) {
        let match = paths.contains { $0.hasSuffix(fileURL.lastPathComponent) }
        guard match else { return }
        lock.lock()
        let suppressed = Date() < suppressionDeadline
        lock.unlock()
        guard !suppressed else { return }
        DispatchQueue.main.async { self.onChange() }
    }

    deinit { stop() }

    private static let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
        guard let info else { return }
        let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
        let array = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
        watcher.fire(for: Array(array.prefix(count)))
    }
}
