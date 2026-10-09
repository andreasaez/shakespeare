import Foundation

/// Allows only one running copy to own the stats file. Two copies would double-count every
/// key and overwrite each other's saves. The lock is an `flock` on a private file, so the
/// system releases it automatically if the app crashes. The Restart button starts the new
/// copy before the old one has quit, so acquiring waits briefly for the old copy to let go.
public final class InstanceLock {
    public enum Outcome {
        case acquired(InstanceLock)
        /// Another copy of the app is running and still holds the lock.
        case heldByAnotherCopy
        /// The lock file couldn't be created (read-only or full disk, odd permissions).
        /// The caller should carry on without a lock rather than refuse to start.
        case unavailable
    }

    private let descriptor: Int32
    private init(descriptor: Int32) { self.descriptor = descriptor }
    deinit { close(descriptor) }  // closing releases the lock

    public static func acquire(directory: URL, timeout: TimeInterval = 5) -> Outcome {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let path = directory.appendingPathComponent(".lock").path

        // O_NOFOLLOW: never open through a symlink. If someone planted one, remove it and retry once.
        func openLock() -> Int32 { open(path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600) }
        var fd = openLock()
        if fd < 0, errno == ELOOP { unlink(path); fd = openLock() }
        guard fd >= 0 else { return .unavailable }
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)  // don't leak the lock into child processes

        let deadline = Date().addingTimeInterval(timeout)
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK else { close(fd); return .unavailable }
            if Date() >= deadline { close(fd); return .heldByAnotherCopy }
            usleep(100_000)
        }
        return .acquired(InstanceLock(descriptor: fd))
    }
}
