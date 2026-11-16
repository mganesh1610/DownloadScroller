import Foundation

/// Watches a folder descriptor without polling or inspecting file contents.
final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    func start(_ url: URL, onChange: @escaping () -> Void) {
        stop()
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib, .revoke], queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.pending?.cancel()
            let work = DispatchWorkItem(block: onChange)
            self?.pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    func stop() {
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
    }

    deinit { stop() }
}
