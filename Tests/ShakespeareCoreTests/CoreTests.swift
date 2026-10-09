import XCTest
@testable import ShakespeareCore

final class CoreTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ day: Int, hour: Int = 12, second: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, second: second))!
    }

    private func date(month: Int, day: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func engine() -> StatsEngine { StatsEngine(calendar: cal) }

    private func type(_ e: StatsEngine, _ n: Int, on d: Date, kind: KeyKind = .letter, app: String? = nil) {
        for i in 0..<n { e.record(kind, at: d.addingTimeInterval(Double(i) * 0.01), app: app) }
    }

    // MARK: Classifier

    func testClassifier() {
        XCTAssertEqual(KeyClassifier.kind(keyCode: 0, hasShortcutModifier: false), .letter)  // a
        XCTAssertEqual(KeyClassifier.kind(keyCode: 49, hasShortcutModifier: false), .space)
        XCTAssertEqual(KeyClassifier.kind(keyCode: 123, hasShortcutModifier: false), .other)  // arrow
        XCTAssertEqual(KeyClassifier.kind(keyCode: 18, hasShortcutModifier: false), .other)  // digit 1
        XCTAssertEqual(KeyClassifier.kind(keyCode: 8, hasShortcutModifier: true), .other)  // ⌘C
    }

    /// The real privacy guarantee: a key code is reduced to a coarse class, so the stored
    /// data cannot depend on WHICH keys were pressed or in what order, only on how many of
    /// each class and when. (Key codes themselves are not anonymous: on a known layout they
    /// map to letters. They just never survive past `KeyClassifier`.)
    func testStoredStatsDoNotDependOnWhichKeysWereTyped() {
        func run(_ codes: [Int]) -> StatsData {
            let e = engine()
            for (i, code) in codes.enumerated() {
                let kind = KeyClassifier.kind(keyCode: code, hasShortcutModifier: false)
                e.record(kind, at: date(1).addingTimeInterval(Double(i)))
            }
            return e.data
        }
        let session1 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]            // a s d f h g z x c v
        let session2 = [17, 31, 32, 34, 35, 37, 38, 40, 45, 46]  // different letters, different order
        XCTAssertEqual(run(session1), run(session2))
        XCTAssertEqual(run(session1), run(session1.reversed()))
        // Control: the test can fail. A space and a digit are different classes and must differ.
        XCTAssertNotEqual(run([0, 49]), run([0, 18]))
    }

    func testQuitAndCloseShortcutsAreIgnoredEntirely() {
        // ⌘Q (12) and ⌘W (13), with or without extra modifiers, aren't counted at all.
        XCTAssertEqual(KeyClassifier.kind(keyCode: 12, hasShortcutModifier: true, hasCommand: true), .ignored)
        XCTAssertEqual(KeyClassifier.kind(keyCode: 13, hasShortcutModifier: true, hasCommand: true), .ignored)
        // Plain q and w are ordinary letters; other ⌘ shortcuts still count as keys (not WPM).
        XCTAssertEqual(KeyClassifier.kind(keyCode: 12, hasShortcutModifier: false, hasCommand: false), .letter)
        XCTAssertEqual(KeyClassifier.kind(keyCode: 13, hasShortcutModifier: false, hasCommand: false), .letter)
        XCTAssertEqual(KeyClassifier.kind(keyCode: 8, hasShortcutModifier: true, hasCommand: true), .other)   // ⌘C
        XCTAssertEqual(KeyClassifier.kind(keyCode: 12, hasShortcutModifier: true, hasCommand: false), .other) // ⌃Q: not ⌘
        XCTAssertFalse(KeyKind.ignored.countsTowardWPM)
    }

    func testIgnoredKeysLeaveNoTraceInStats() {
        let e = engine()
        e.record(.ignored, at: date(1), app: "System Settings")
        XCTAssertTrue(e.data.days.isEmpty)
        XCTAssertFalse(e.isDirty)
        e.record(.other, at: date(1), app: "System Settings")   // an ordinary shortcut does count
        XCTAssertEqual(e.keys(on: date(1)), 1)
    }

    // MARK: WPM

    func testWPMSteadyTyping() {
        var t = WPMTracker()
        var last = 0.0
        for i in 0..<300 { last = t.record(at: Double(i) * 0.2) }  // 300 keys in 60s
        XCTAssertEqual(last, 60, accuracy: 1)
    }

    func testWPMBurstDoesNotInflate() {
        var t = WPMTracker()
        var last = 0.0
        for i in 0..<50 { last = t.record(at: Double(i) * 0.1) }  // 50 keys in 5s
        XCTAssertEqual(last, 10, accuracy: 0.01)  // 50 keys / 5, not extrapolated
    }

    func testWPMOldKeysExpire() {
        var t = WPMTracker()
        for i in 0..<100 { t.record(at: Double(i) * 0.1) }
        XCTAssertEqual(t.record(at: 1000), 0.2, accuracy: 0.001)
    }

    // MARK: Engine

    func testShortcutsAndArrowsDoNotRaiseWPM() {
        let e = engine()
        type(e, 500, on: date(1), kind: .other)
        let s = e.summary(lastDays: 1, endingAt: date(1))
        XCTAssertEqual(s.keys, 500)
        XCTAssertEqual(s.textKeys, 0)
        XCTAssertEqual(s.bestWPM, 0)
    }

    func testLastDaysAndToday() {
        let e = engine()
        type(e, 10, on: date(5))
        type(e, 3, on: date(3))
        let days = e.lastDays(14, endingAt: date(5))
        XCTAssertEqual(days.count, 14)
        XCTAssertEqual(days.last?.keys, 10)
        XCTAssertEqual(days[days.count - 3].keys, 3)
    }

    func testStreakCountsOnlyDaysOverThreshold() {
        let e = engine()
        for d in [1, 2, 3] { type(e, 60, on: date(d)) }
        type(e, 49, on: date(4))  // just under: breaks the streak
        for d in [5, 6] { type(e, 50, on: date(d)) }
        XCTAssertEqual(e.streak(endingAt: date(6)), 2)
    }

    func testQuietTodayDoesNotBreakStreak() {
        let e = engine()
        for d in [3, 4] { type(e, 80, on: date(d)) }
        XCTAssertEqual(e.streak(endingAt: date(5)), 2)
        XCTAssertEqual(e.streak(endingAt: date(7)), 0)
    }

    func testBusiestHourAndTopApps() {
        let e = engine()
        type(e, 5, on: date(1, hour: 9), app: "Xcode")
        type(e, 20, on: date(1, hour: 22), app: "Notes")
        type(e, 8, on: date(2, hour: 22), app: "Xcode")
        let s = e.summary(lastDays: nil, endingAt: date(2))
        XCTAssertEqual(s.busiestHour, 22)
        XCTAssertEqual(s.topApps.map(\.name), ["Notes", "Xcode"])
        XCTAssertEqual(s.topApps.first?.keys, 20)
    }

    func testAppsAreNotStoredWhenTrackingIsOff() {
        let e = engine()
        type(e, 10, on: date(1), app: nil)
        XCTAssertTrue(e.data.days.values.allSatisfy { $0.apps.isEmpty })
    }

    func testClearAppsKeepsOtherStats() {
        let e = engine()
        type(e, 10, on: date(1), app: "Notes")
        e.clearApps()
        let s = e.summary(lastDays: nil, endingAt: date(1))
        XCTAssertEqual(s.keys, 10)
        XCTAssertTrue(s.topApps.isEmpty)
    }

    // MARK: Persistence

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("shakespeare-test-\(UUID().uuidString)")
            .appendingPathComponent("stats.json")
    }

    func testPersistenceRoundTripAndPermissions() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let e = engine()
        type(e, 12, on: date(1))
        try store.save(e.data)
        XCTAssertEqual(store.load(), e.data)

        let file = try FileManager.default.attributesOfItem(atPath: store.url.path)
        let dir = try FileManager.default.attributesOfItem(atPath: store.directory.path)
        XCTAssertEqual(file[.posixPermissions] as? Int, 0o600)
        XCTAssertEqual(dir[.posixPermissions] as? Int, 0o700)
    }

    func testCorruptFileIsMovedAsideNotOverwritten() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)
        XCTAssertEqual(store.load(), StatsData())
        let backup = store.directory.appendingPathComponent("stats.corrupt.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
    }

    /// Guards the privacy promise: the stored schema is counters only.
    func testStoredSchemaContainsOnlyCounters() throws {
        let e = engine()
        type(e, 3, on: date(1))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(e.data)) as! [String: Any]
        let day = ((json["days"] as! [String: Any]).values.first) as! [String: Any]
        XCTAssertEqual(Set(day.keys), ["keys", "textKeys", "bestWPM", "hours", "apps"])
    }

    // MARK: Hostile or damaged data

    func testTamperedStatsFileCannotCrashTheApp() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let longName = String(repeating: "A", count: 5_000)
        let json = """
        {"version":1,"days":{
          "2026-03-01":{"keys":-5,"textKeys":9999999999999,"bestWPM":1e9,"hours":[1,2,3],"apps":{"\(longName)":-7,"Notes":4}},
          "not-a-date":{"keys":1,"textKeys":1,"bestWPM":0,"hours":[],"apps":{}},
          "2026-13-45":{"keys":1,"textKeys":1,"bestWPM":0,"hours":[],"apps":{}}
        }}
        """
        try Data(json.utf8).write(to: store.url)

        let loaded = store.load()
        XCTAssertEqual(Set(loaded.days.keys), ["2026-03-01"])          // bad keys dropped
        let day = try XCTUnwrap(loaded.days["2026-03-01"])
        XCTAssertEqual(day.hours.count, 24)                              // repaired to 24
        XCTAssertEqual(day.keys, 0)                                      // negative clamped
        XCTAssertEqual(day.textKeys, StatsData.maxCount)                 // huge clamped
        XCTAssertEqual(day.bestWPM, 400)
        XCTAssertTrue(day.apps.keys.allSatisfy { $0.count <= StatsData.maxAppNameLength })
        XCTAssertTrue(day.apps.values.allSatisfy { $0 >= 0 })

        // The engine keeps working on repaired data (this used to be an out-of-range trap).
        let e = StatsEngine(data: loaded, calendar: cal)
        e.record(.letter, at: date(1))
        XCTAssertEqual(e.keys(on: date(1)), 1)
    }

    func testOversizedStatsFileIsRejected() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data(count: StatsPersistence.maxFileBytes + 1).write(to: store.url)
        XCTAssertEqual(store.load(), StatsData())
    }

    func testExistingLooseDirectoryIsTightenedOnSave() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o755])
        try store.save(StatsData())
        let attrs = try FileManager.default.attributesOfItem(atPath: store.directory.path)
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o700)
    }

    func testKeyFloodIsBounded() {
        var t = WPMTracker()
        var wpm = 0.0
        for i in 0..<200_000 { wpm = t.record(at: Double(i) * 0.0001) }  // 10,000 keys/sec
        XCTAssertLessThanOrEqual(wpm, Double(WPMTracker.maxStamps) / WPMTracker.keysPerWord)
        let e = engine()
        for i in 0..<5_000 { e.record(.letter, at: date(1).addingTimeInterval(Double(i) * 0.0001)) }
        XCTAssertLessThanOrEqual(e.summary(lastDays: 1, endingAt: date(1)).bestWPM, StatsData.maxWPM)
    }

    /// Deterministic fuzzing: hostile stats files must never crash the loader or any query.
    func testSeededFuzzOfStatsFiles() throws {
        var seed: UInt64 = 0xC0FFEE
        func next() -> UInt64 { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return seed >> 11 }
        func number() -> String {
            let specials = ["0", "-1", "9223372036854775807", "-9223372036854775808", "1e308", "1e400", "0.5", "null", "\"x\"", "[]", "{}", "true"]
            return next() % 3 == 0 ? specials[Int(next() % UInt64(specials.count))] : String(Int(next() % 100_000) - 1_000)
        }
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)

        for _ in 0..<400 {
            let dayCount = Int(next() % 6)
            let days = (0..<dayCount).map { _ -> String in
                let key = ["2026-03-\(10 + Int(next() % 15))", "2026-03-0\(1 + Int(next() % 9))", "x", "", "9999-99-99", "2026-3-1"][Int(next() % 6)]
                let hours = (0..<Int(next() % 30)).map { _ in number() }.joined(separator: ",")
                let apps = (0..<Int(next() % 4)).map { _ in "\"app\(next() % 5)\":\(number())" }.joined(separator: ",")
                return "\"\(key)\":{\"keys\":\(number()),\"textKeys\":\(number()),\"bestWPM\":\(number()),\"hours\":[\(hours)],\"apps\":{\(apps)}}"
            }
            var text = "{\"version\":1,\"days\":{\(days.joined(separator: ","))}}"
            if next() % 8 == 0 { text = String(text.dropLast(Int(next() % 12))) }   // truncated JSON
            if next() % 12 == 0 { text = String(text.shuffled().prefix(60)) }          // garbage
            try Data(text.utf8).write(to: store.url)

            let e = StatsEngine(data: store.load(), calendar: cal)   // must not trap
            e.record(.letter, at: date(5), app: "Fuzz")
            _ = e.summary(lastDays: nil, endingAt: date(5))
            _ = e.summary(lastDays: 14, endingAt: date(5))
            _ = e.lastDays(14, endingAt: date(5))
            _ = e.streak(endingAt: date(5))
            _ = e.badgeStatuses(now: date(5))
            _ = e.nextBadge(now: date(5))
            _ = e.busiestDay()
            _ = e.totalWords
            XCTAssertEqual(e.lastDays(14, endingAt: date(5)).count, 14)
            XCTAssertTrue(e.data.days.values.allSatisfy { $0.hours.count == 24 && $0.keys >= 0 && $0.bestWPM <= StatsData.maxWPM })
        }
    }

    // MARK: PNG scrubbing

    private func chunk(_ type: String, _ body: [UInt8] = []) -> [UInt8] {
        let n = body.count
        return [UInt8(n >> 24 & 255), UInt8(n >> 16 & 255), UInt8(n >> 8 & 255), UInt8(n & 255)]
            + Array(type.utf8) + body + [0, 0, 0, 0]   // CRC is copied, not checked
    }

    private func chunkTypes(_ data: Data) -> [String] {
        let b = [UInt8](data)
        var i = 8, out: [String] = []
        while i + 12 <= b.count {
            let n = Int(b[i]) << 24 | Int(b[i + 1]) << 16 | Int(b[i + 2]) << 8 | Int(b[i + 3])
            out.append(String(decoding: b[(i + 4)..<(i + 8)], as: UTF8.self))
            i += 12 + n
        }
        return out
    }

    func testPNGScrubberStripsMetadataAndKeepsImage() throws {
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let png = sig + chunk("IHDR", Array(repeating: 1, count: 13)) + chunk("eXIf", [1, 2, 3])
            + chunk("tEXt", Array("Author\0someone".utf8)) + chunk("tIME", [0, 1, 2, 3, 4, 5, 6])
            + chunk("iCCP", [9]) + chunk("sRGB", [0]) + chunk("IDAT", [7, 7, 7]) + chunk("IEND")
        let scrubbed = try XCTUnwrap(PNGScrubber.scrub(Data(png)))
        XCTAssertEqual(chunkTypes(scrubbed), ["IHDR", "sRGB", "IDAT", "IEND"])
    }

    func testPNGScrubberFailsClosedOnMalformedInput() {
        XCTAssertNil(PNGScrubber.scrub(Data("not a png".utf8)))
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        XCTAssertNil(PNGScrubber.scrub(Data(sig + [0xFF, 0xFF, 0xFF, 0xFF, 0x49, 0x44, 0x41, 0x54])))  // huge length
        XCTAssertNil(PNGScrubber.scrub(Data(sig + chunk("IHDR", Array(repeating: 1, count: 13)))))     // no IEND
    }

    // MARK: Edge cases: files, processes, text, time

    func testSaveDoesNotFollowAPlantedSymlink() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let victim = store.directory.appendingPathComponent("victim.txt")
        try Data("VICTIM".utf8).write(to: victim)
        // An attacker pre-plants the predictable temp path as a symlink to a file they want overwritten.
        try FileManager.default.createSymbolicLink(
            at: store.directory.appendingPathComponent(".stats.json.tmp"), withDestinationURL: victim)

        let e = engine()
        type(e, 5, on: date(1))
        try store.save(e.data)

        XCTAssertEqual(try String(contentsOf: victim, encoding: .utf8), "VICTIM")   // untouched
        XCTAssertEqual(store.load(), e.data)                                         // real file is correct
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory.appendingPathComponent(".stats.json.tmp").path))
        let attrs = try FileManager.default.attributesOfItem(atPath: store.url.path)
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o600)
    }

    func testSaveReplacesASymlinkedStatsFileInsteadOfWritingThroughIt() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let victim = store.directory.appendingPathComponent("victim.txt")
        try Data("VICTIM".utf8).write(to: victim)
        try FileManager.default.createSymbolicLink(at: store.url, withDestinationURL: victim)
        try store.save(StatsData())
        XCTAssertEqual(try String(contentsOf: victim, encoding: .utf8), "VICTIM")
        XCTAssertEqual(store.load(), StatsData())
    }

    func testOnlyOneCopyCanHoldTheInstanceLock() throws {
        let dir = tempURL().deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: dir) }
        guard case .acquired(let first) = InstanceLock.acquire(directory: dir, timeout: 1) else { return XCTFail("first copy should get the lock") }
        guard case .heldByAnotherCopy = InstanceLock.acquire(directory: dir, timeout: 0.3) else { return XCTFail("second copy must be refused") }
        let attrs = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(".lock").path)
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o600)
        withExtendedLifetime(first) {}
    }

    func testLockIsFreedWhenTheFirstCopyQuits() {
        let dir = tempURL().deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: dir) }
        var first: InstanceLock?
        if case .acquired(let lock) = InstanceLock.acquire(directory: dir, timeout: 1) { first = lock }
        XCTAssertNotNil(first)
        first = nil   // the first copy quits (Restart handover)
        guard case .acquired = InstanceLock.acquire(directory: dir, timeout: 1) else { return XCTFail("lock should be free") }
    }

    func testUnwritableLocationMeansUnavailableNotRefusal() throws {
        // A *file* where the folder should be: the lock can't be created, and the app must still start.
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("shk-blocker-\(UUID().uuidString)")
        try Data("x".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        guard case .unavailable = InstanceLock.acquire(directory: blocker, timeout: 0.2) else { return XCTFail("expected .unavailable") }
    }

    func testPlantedLockSymlinkDoesNotBlockStartupOrGetFollowed() throws {
        let dir = tempURL().deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let victim = dir.appendingPathComponent("victim.txt")
        try Data("VICTIM".utf8).write(to: victim)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent(".lock"), withDestinationURL: victim)
        guard case .acquired(let lock) = InstanceLock.acquire(directory: dir, timeout: 1) else { return XCTFail("should recover from a planted symlink") }
        XCTAssertEqual(try String(contentsOf: victim, encoding: .utf8), "VICTIM")
        withExtendedLifetime(lock) {}
    }

    // MARK: Hostile file types and shapes

    func testSpecialFilesInPlaceOfStatsJSONAreRejectedQuickly() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let fm = FileManager.default
        try fm.createDirectory(at: store.directory, withIntermediateDirectories: true)

        func expectRejected(_ label: String, plant: () throws -> Void) throws {
            try? fm.removeItem(at: store.url)
            try? fm.removeItem(at: store.directory.appendingPathComponent("stats.corrupt.json"))
            try plant()
            let started = Date()
            XCTAssertEqual(store.load(), StatsData(), label)
            XCTAssertLessThan(Date().timeIntervalSince(started), 2, "\(label) must not hang or read forever")
        }
        try expectRejected("symlink to /dev/zero") { try fm.createSymbolicLink(atPath: store.url.path, withDestinationPath: "/dev/zero") }
        try expectRejected("named pipe") { XCTAssertEqual(mkfifo(store.url.path, 0o600), 0) }
        try expectRejected("folder") { try fm.createDirectory(at: store.url, withIntermediateDirectories: false) }
        try expectRejected("symlink to a real stats file") {
            let real = store.directory.appendingPathComponent("real.json")
            try Data(#"{"version":1,"days":{}}"#.utf8).write(to: real)
            try fm.createSymbolicLink(at: store.url, withDestinationURL: real)
        }
    }

    func testDeeplyNestedJSONIsRejectedWithoutCrashing() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        for opener in ["[", #"{"a":"#] {
            try Data(String(repeating: opener, count: 400_000).utf8).write(to: store.url)   // stack-exhaustion attempt
            let started = Date()
            XCTAssertEqual(store.load(), StatsData())
            XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        }
    }

    func testHugeNumberOfDaysIsBoundedAndFast() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        var entries: [String] = []
        entries.reserveCapacity(60_000)
        outer: for year in 2000...2999 {
            for month in 1...12 {
                for day in 1...28 {
                    entries.append(#""\#(year)-\#(String(format: "%02d", month))-\#(String(format: "%02d", day))":{"keys":1,"textKeys":1,"bestWPM":0,"hours":[],"apps":{}}"#)
                    if entries.count >= 60_000 { break outer }
                }
            }
        }
        try Data("{\"version\":1,\"days\":{\(entries.joined(separator: ","))}}".utf8).write(to: store.url)
        let started = Date()
        let loaded = store.load()
        XCTAssertLessThanOrEqual(loaded.days.count, StatsData.maxDays)
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
        _ = StatsEngine(data: loaded, calendar: cal).badgeStatuses(now: date(1))
    }

    /// Byte-level fuzzing: flip, insert, delete and truncate bytes in a valid file.
    func testByteLevelFuzzNeverCrashes() throws {
        let store = StatsPersistence(url: tempURL())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let seedEngine = engine()
        for d in 1...6 { type(seedEngine, 40, on: date(d), app: d.isMultiple(of: 2) ? "Notes" : "Xcode") }
        try store.save(seedEngine.data)
        let valid = [UInt8](try Data(contentsOf: store.url))

        var seed: UInt64 = 0xDEADBEEF
        func next() -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int(seed >> 33) }
        for _ in 0..<2_000 {
            var bytes = valid
            for _ in 0..<(1 + next() % 8) {
                guard !bytes.isEmpty else { break }
                let i = next() % bytes.count
                switch next() % 4 {
                case 0: bytes[i] = UInt8(truncatingIfNeeded: next())      // overwrite
                case 1: bytes.insert(UInt8(truncatingIfNeeded: next()), at: i)
                case 2: bytes.remove(at: i)
                default: bytes = Array(bytes.prefix(i))                    // truncate
                }
            }
            try Data(bytes).write(to: store.url)
            let e = StatsEngine(data: store.load(), calendar: cal)
            e.record(.letter, at: date(7), app: "Fuzz")
            _ = e.summary(lastDays: nil, endingAt: date(7)); _ = e.badgeStatuses(now: date(7))
            _ = e.nextBadge(now: date(7)); _ = e.streak(endingAt: date(7)); _ = e.busiestDay()
            XCTAssertTrue(e.data.days.values.allSatisfy { $0.hours.count == 24 && $0.keys >= 0 })
        }
    }

    func testAppNamesAreCleanedOfInvisibleAndBidiCharacters() {
        XCTAssertEqual(StatsData.cleanAppName("\u{202E}Notes"), "Notes")            // right-to-left override
        XCTAssertEqual(StatsData.cleanAppName("Xc\u{200B}ode"), "Xcode")            // zero-width space
        XCTAssertEqual(StatsData.cleanAppName("Mail\u{0007}\n"), "Mail")           // bell + newline
        XCTAssertEqual(StatsData.cleanAppName("  Safari  "), "Safari")
        XCTAssertEqual(StatsData.cleanAppName("Café ☕️"), "Café ☕️")                // real text is kept
        XCTAssertNil(StatsData.cleanAppName("\u{202E}\u{200B}  "))                 // nothing printable left
        XCTAssertEqual(StatsData.cleanAppName(String(repeating: "A", count: 500))?.count, StatsData.maxAppNameLength)
    }

    func testRecordingCleansAndCapsAppNames() {
        let e = engine()
        e.record(.letter, at: date(1), app: "\u{202E}Notes")
        e.record(.letter, at: date(1), app: "Notes")
        XCTAssertEqual(e.summary(lastDays: nil, endingAt: date(1)).topApps, [AppCount(name: "Notes", keys: 2)])
        for i in 0..<(StatsData.maxAppsPerDay + 50) { e.record(.letter, at: date(1), app: "App\(i)") }
        XCTAssertLessThanOrEqual(e.data.days.values.first!.apps.count, StatsData.maxAppsPerDay)
    }

    func testRemoveAppKeepsKeyCounts() {
        let e = engine()
        type(e, 5, on: date(1), app: "Shakespeare")
        type(e, 20, on: date(1), app: "Notes")
        type(e, 3, on: date(2), app: "Shakespeare")
        XCTAssertTrue(e.removeApp(named: "Shakespeare"))
        let all = e.summary(lastDays: nil, endingAt: date(2))
        XCTAssertEqual(all.topApps.map(\.name), ["Notes"])
        XCTAssertEqual(all.keys, 28)                         // totals untouched
        XCTAssertFalse(e.removeApp(named: "Shakespeare"))    // nothing left to remove
    }

    func testWrongSystemClockIsIgnoredNotRecorded() {
        let e = engine()
        e.record(.letter, at: Date(timeIntervalSince1970: 0))             // 1970: clock reset
        e.record(.letter, at: Date(timeIntervalSince1970: 400_000_000_000)) // year ~14,700
        XCTAssertTrue(e.data.days.isEmpty)
        e.record(.letter, at: date(1))
        XCTAssertEqual(e.data.days.count, 1)
    }

    func testDayKeysAreGregorianWhateverCalendarTheSystemUses() {
        XCTAssertEqual(StatsEngine.defaultCalendar.identifier, .gregorian)
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = .current
        let when = greg.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 12))!
        let e = StatsEngine()
        e.record(.letter, at: when)
        XCTAssertEqual(Array(e.data.days.keys), ["2026-03-05"])
        // A Japanese-calendar engine would key the same day as an era year, which is why we pin Gregorian.
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = .current
        let eraKey = StatsEngine(calendar: japanese)
        eraKey.record(.letter, at: when)
        XCTAssertNotEqual(Array(eraKey.data.days.keys), ["2026-03-05"])
    }

    // MARK: Fun facts

    func testFunFacts() {
        XCTAssertEqual(FunFacts.hourLabel(0), "12 AM")
        XCTAssertEqual(FunFacts.hourLabel(13), "1 PM")
        XCTAssertEqual(FunFacts.travelMetres(keys: 1_000_000), 1000, accuracy: 0.001)
        XCTAssertEqual(FunFacts.hamlets(textKeys: 150_000), 1, accuracy: 0.001)
    }

    func testBusiestDay() {
        let e = engine()
        XCTAssertNil(e.busiestDay())
        type(e, 10, on: date(1))
        type(e, 30, on: date(2))
        type(e, 30, on: date(3))  // tie: the earlier day wins
        XCTAssertEqual(e.busiestDay()?.keys, 30)
        XCTAssertEqual(e.busiestDay()?.date, date(2, hour: 0))
        XCTAssertEqual(FunFacts.novelPages(words: 10_000), 40, accuracy: 0.001)
    }

    func testLandmarkLadderAscendsAndAdvancesAt100Percent() {
        let metres = FunFacts.landmarks.map(\.metres)
        XCTAssertEqual(metres, metres.sorted())
        XCTAssertEqual(FunFacts.nextLandmark(metres: 0)?.name, "the Tower of London")
        // Just under 100%: still on the same landmark. At 100%: moves to the next.
        XCTAssertEqual(FunFacts.nextLandmark(metres: 55.9)?.name, "the Leaning Tower of Pisa")
        XCTAssertEqual(FunFacts.nextLandmark(metres: 56)?.name, "Big Ben")
        XCTAssertNil(FunFacts.nextLandmark(metres: 21_196_000))
    }

    func testTravelFactText() {
        XCTAssertEqual(FunFacts.travelFact(metres: 28),
                       "Your keys have travelled 28.0 m, 50% of the way to the Leaning Tower of Pisa.")
        XCTAssertTrue(FunFacts.travelFact(metres: 60).hasSuffix("to Big Ben."))
        XCTAssertTrue(FunFacts.travelFact(metres: 50_000_000).contains("2.4× the length of the Great Wall"))
    }

    // MARK: Badges

    func testBadgeLadderIsStrictlyIncreasing() {
        let words = BadgeCatalog.all.map(\.words)
        XCTAssertEqual(words, words.sorted())
        XCTAssertEqual(Set(words).count, words.count)
        XCTAssertEqual(BadgeCatalog.all.first { $0.id == "hamlet" }?.words, 30_000)
    }

    func testBadgesEarnedWithDatesThisMonth() {
        let e = engine()
        type(e, 500, on: date(1))   // 100 words: Couplet only
        type(e, 500, on: date(3))   // 200 words: Sonnet crossed on day 3
        let s = e.badgeStatuses(now: date(5))
        let couplet = s.first { $0.badge.id == "couplet" }!
        let sonnet = s.first { $0.badge.id == "sonnet" }!
        let soliloquy = s.first { $0.badge.id == "soliloquy" }!
        XCTAssertEqual(couplet.earnedThisMonthOn, date(1, hour: 0))
        XCTAssertEqual(sonnet.earnedThisMonthOn, date(3, hour: 0))
        XCTAssertFalse(soliloquy.isCollected)
        XCTAssertEqual(e.monthWords(containing: date(5)), 200)
    }

    func testProgressResetsEachMonthButCollectionStays() {
        let e = engine()
        type(e, 1_000, on: date(month: 3, day: 5))  // 200 words in March: Couplet + Sonnet
        let april = date(month: 4, day: 2)
        type(e, 100, on: april)                      // 20 words in April: Couplet again
        let s = e.badgeStatuses(now: april)
        let couplet = s.first { $0.badge.id == "couplet" }!
        let sonnet = s.first { $0.badge.id == "sonnet" }!
        XCTAssertEqual(couplet.timesEarned, 2)       // earned in March and April
        XCTAssertTrue(couplet.isEarnedThisMonth)
        XCTAssertEqual(sonnet.timesEarned, 1)        // March only
        XCTAssertFalse(sonnet.isEarnedThisMonth)     // progress reset
        XCTAssertTrue(sonnet.isCollected)            // but still in the collection
        XCTAssertEqual(sonnet.firstEarned, date(month: 3, day: 5, hour: 0))
        XCTAssertEqual(e.monthWords(containing: april), 20)
    }

    func testNextBadgeProgressIsPerMonth() {
        let e = engine()
        type(e, 500, on: date(month: 2, day: 1))     // big February must not count in March
        let march = date(month: 3, day: 1)
        type(e, 500, on: march)                       // 100 words; previous = Couplet, next = Sonnet
        let next = e.nextBadge(now: march)
        XCTAssertEqual(next?.badge.id, "sonnet")
        XCTAssertEqual(next?.progress ?? 0, 0.8, accuracy: 0.001)
    }

    func testNonTextKeysDoNotEarnBadges() {
        let e = engine()
        type(e, 5_000, on: date(1), kind: .other)
        XCTAssertTrue(e.badgeStatuses(now: date(1)).allSatisfy { !$0.isCollected })
    }

    func testCompleteWorksIsRepeatableEveryMonth() {
        var data = StatsData()
        for key in ["2026-03-10", "2026-04-10"] {
            var day = DayRecord()
            day.textKeys = 884_000 * 5
            data.days[key] = day
        }
        let e = StatsEngine(data: data, calendar: cal)
        let april = date(month: 4, day: 20)
        XCTAssertNil(e.nextBadge(now: april))
        let complete = e.badgeStatuses(now: april).first { $0.badge.id == "complete" }!
        XCTAssertEqual(complete.timesEarned, 2)
        XCTAssertTrue(complete.isEarnedThisMonth)
    }
}
