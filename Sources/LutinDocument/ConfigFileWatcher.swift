import Foundation

public extension Notification.Name {
    /// Posted by `LutinProjectDocument` after a successful reload
    /// triggered by an external write to its `configURL`. The object is
    /// the document instance. UI uses this to surface a brief
    /// "reloaded from disk" badge so users (and especially users
    /// driving Lutin from an agent that rewrites the YAML) know the
    /// canvas now reflects the on-disk state, not a stale snapshot.
    static let lutinDocumentReloadedFromDisk =
        Notification.Name("LutinDocumentReloadedFromDisk")
}

/// Watches a single config file URL for external writes and invokes a
/// callback on the main queue when one is detected. Self-writes (via
/// `LutinProjectDocument.save`) are suppressed by a short cool-down
/// after `noteSelfWrite()`.
///
/// **Why a fresh descriptor per event.** `LutinProjectDocument.save`
/// uses `FileManager.replaceItemAt`, which is atomic: it rotates the
/// inode under the URL by renaming a tmp file over it. Our dispatch
/// source's file descriptor points at the *old* vnode after that and
/// stops receiving events — agents that overwrite via the same atomic
/// dance (most editors, all sane CLI tools) would silently never wake
/// us up again. Re-`open()`-ing on every event covers both our own
/// saves and any external atomic rewrites.
public final class ConfigFileWatcher: @unchecked Sendable {
    private let url: URL
    private let onExternalChange: @Sendable () -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "lutin.config-file-watcher")
    /// Window after `noteSelfWrite()` during which any inbound event is
    /// assumed to originate from our own atomic save. 500ms is generous
    /// (the kernel typically delivers within a few ms) and the
    /// debounced autosave runs no faster than once per 500ms anyway, so
    /// adjacent self-writes can't masquerade as external.
    private let selfWriteSuppressionInterval: TimeInterval = 0.5
    private var lastSelfWriteAt: Date?

    public init(url: URL, onExternalChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onExternalChange = onExternalChange
    }

    public func start() {
        queue.async { [weak self] in self?.attach() }
    }

    public func stop() {
        queue.async { [weak self] in self?.detach() }
    }

    /// Call immediately before an internal `save()` so that the
    /// dispatch event triggered by our own atomic write is ignored.
    public func noteSelfWrite() {
        queue.async { [weak self] in
            self?.lastSelfWriteAt = Date()
        }
    }

    private func attach() {
        detach()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )
        src.setEventHandler { [weak self] in self?.handleEvent() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func detach() {
        source?.cancel()
        source = nil
    }

    private func handleEvent() {
        // Always re-attach — the fd is either invalidated by an atomic
        // replace, or the source has signalled .delete/.rename and
        // won't fire again on this descriptor.
        let last = lastSelfWriteAt
        attach()
        if let last, Date().timeIntervalSince(last) < selfWriteSuppressionInterval {
            return
        }
        let callback = onExternalChange
        DispatchQueue.main.async { callback() }
    }
}
