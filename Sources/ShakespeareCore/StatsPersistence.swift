import Foundation

/// Reads and writes stats as JSON in the user's Application Support folder.
/// The directory is created 0700 and the file 0600 (owner-only).
public struct StatsPersistence {
    public let url: URL
    static let maxFileBytes = 10_000_000

    public static var defaultURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shakespeare", isDirectory: true)
            .appendingPathComponent("stats.json")
    }

    public init(url: URL = StatsPersistence.defaultURL) { self.url = url }

    public var directory: URL { url.deletingLastPathComponent() }

    /// Where an unreadable stats file is moved aside. It can still hold old counts.
    var corruptBackupURL: URL { url.deletingPathExtension().appendingPathExtension("corrupt.json") }
    var tempURL: URL { directory.appendingPathComponent(".stats.json.tmp") }

    private enum ReadResult {
        case missing
        case rejected   // not a regular file, a symlink, unreadable or too large
        case data(Data)
    }

    /// Reads the stats file without trusting it. It must be a regular file (not a symlink,
    /// pipe, device or folder) no larger than `maxFileBytes`, and we never read more than that.
    /// This stops a file swapped for `/dev/zero` or a named pipe from hanging or exhausting
    /// memory at launch.
    private func readBounded() -> ReadResult {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard fd >= 0 else { return errno == ENOENT ? .missing : .rejected }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_size <= off_t(Self.maxFileBytes) else { return .rejected }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while data.count <= Self.maxFileBytes {
            let n = read(fd, &buffer, buffer.count)
            if n < 0 { return .rejected }
            if n == 0 { return .data(data) }
            data.append(buffer, count: n)
        }
        return .rejected
    }

    /// Returns empty stats if there is no file. A file we can't trust or decode is moved
    /// aside (never silently overwritten) and empty stats are returned.
    public func load() -> StatsData {
        switch readBounded() {
        case .missing:
            return StatsData()
        case .data(let raw):
            if let decoded = try? JSONDecoder().decode(StatsData.self, from: raw) { return decoded.sanitized() }
        case .rejected:
            break
        }
        try? FileManager.default.removeItem(at: corruptBackupURL)
        try? FileManager.default.moveItem(at: url, to: corruptBackupURL)
        return StatsData()
    }

    public func save(_ data: StatsData) throws {
        let fm = FileManager.default
        try fm.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        // createDirectory only applies permissions to a folder it creates; tighten an existing one too.
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        var info = stat()
        guard stat(directory.path, &info) == 0, info.st_uid == geteuid() else {
            throw POSIXError(.EPERM)  // never write into a folder someone else owns
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let bytes = try encoder.encode(data)

        // Write a private temp file, then atomically rename it over the real one. The temp file
        // is created with O_EXCL | O_NOFOLLOW after removing any leftover, so a planted symlink
        // or stale file can't redirect the write somewhere else.
        let temp = tempURL
        unlink(temp.path)
        let fd = open(temp.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var failure: Int32 = 0
        bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = write(fd, buffer.baseAddress! + offset, buffer.count - offset)
                if written < 0 { failure = errno; return }
                offset += written
            }
        }
        if failure == 0, fsync(fd) != 0 { failure = errno }
        close(fd)
        if failure == 0, rename(temp.path, url.path) != 0 { failure = errno }
        if failure != 0 {
            unlink(temp.path)
            throw POSIXError(POSIXErrorCode(rawValue: failure) ?? .EIO)
        }
    }

    /// Erases every copy of the user's counts: the stats file, a moved-aside corrupt copy and
    /// any leftover temp file. ("Delete all data" must leave nothing behind.)
    public func delete() throws {
        for file in [url, corruptBackupURL, tempURL] {
            // removeItem deletes a symlink itself, never its target. A missing file is fine.
            do { try FileManager.default.removeItem(at: file) } catch let error as CocoaError where error.code == .fileNoSuchFile {}
        }
    }
}
