# Database & Storage System Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single nio.db SQLite database with a multi-database, network-layer-sharded architecture that supports concurrent writes, streaming I/O, and extensible multi-protocol storage.

**Architecture:** Per-CaptureTask directory containing 4 WAL-mode SQLite databases (transport/protocol/decoded/state) plus a global catalog.db. Each database has its own serial write queue for lock-free concurrency. Payloads stored as files with streaming read/write. Background decode queue processes raw payloads into searchable decoded form.

**Tech Stack:** Swift 5.9, SQLite.swift 0.16+, SwiftNIO, Apple Compression framework, FTS5

**Spec:** `docs/superpowers/specs/2026-03-19-database-storage-redesign.md`

---

## File Structure

All new files live under `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/`. This isolates the new storage layer from the existing ActiveSQLite-based code, enabling the gradual migration strategy (dual-write → switch → cleanup).

```
LocalPackages/TunnelServices/Sources/TunnelServices/Storage/
├── PathManager.swift                    # All file path computation
├── FlowIdGenerator.swift                # Thread-safe flowId generation
├── DatabaseManager.swift                # Global singleton, catalog.db, connection pool
├── TaskDatabaseGroup.swift              # Per-task 4-database bundle + write queues
├── Schema/
│   ├── CatalogSchema.swift              # catalog.db DDL
│   ├── TransportSchema.swift            # transport.db DDL
│   ├── ProtocolSchema.swift             # protocol.db DDL
│   ├── DecodedSchema.swift              # decoded.db DDL
│   └── StateSchema.swift                # state.db DDL
├── DAO/
│   ├── CatalogDAO.swift                 # capture_task, rule, breakpoint CRUD
│   ├── FlowDAO.swift                    # flow table insert/update/query
│   ├── PacketDAO.swift                  # packet table insert (uses BatchWriter)
│   ├── DecodedEntryDAO.swift            # decoded_entry insert/query + FTS search
│   ├── ConnectionDAO.swift              # connection table CRUD
│   ├── ModifyLogDAO.swift               # modify_log insert/query
│   └── TaskStatsDAO.swift               # task_stats singleton row update/read
├── Model/
│   ├── FlowRecord.swift                 # FlowRecord struct + FlowStatus enum
│   ├── PacketRow.swift                  # PacketRow struct (transport layer)
│   ├── DecodedEntry.swift               # DecodedEntry struct
│   ├── ConnectionRecord.swift           # ConnectionRecord struct
│   └── ModifyLogEntry.swift             # ModifyLogEntry struct
├── Payload/
│   ├── PayloadWriter.swift              # Streaming file writer (32KB buffer)
│   ├── PayloadReader.swift              # Streaming file reader (64KB chunks)
│   ├── PayloadDecoder.swift             # Streaming decompress pipeline
│   ├── TextAccumulator.swift            # Extract searchable text from stream
│   └── DecompressStream.swift           # compression_stream wrapper
├── BatchWriter.swift                    # Batched transaction writer for transport.db
├── DecodeScheduler.swift                # Background decode queue (async + sync paths)
├── TaskStatsSync.swift                  # Periodic stats sync to catalog.db
├── Protocol/
│   ├── ProtocolRecorder.swift           # Protocol interface + SearchKeyMapping
│   └── HTTPRecorder.swift               # HTTP protocol recorder implementation
└── Migration/
    └── LegacyMigrator.swift             # nio.db → new architecture migration

LocalPackages/TunnelServices/Tests/TunnelServicesTests/
├── Storage/
│   ├── PathManagerTests.swift
│   ├── FlowIdGeneratorTests.swift
│   ├── SchemaTests.swift
│   ├── FlowDAOTests.swift
│   ├── PacketDAOTests.swift
│   ├── BatchWriterTests.swift
│   ├── PayloadWriterTests.swift
│   ├── PayloadReaderTests.swift
│   ├── PayloadDecoderTests.swift
│   ├── TextAccumulatorTests.swift
│   ├── DecodeSchedulerTests.swift
│   ├── DecodedEntryDAOTests.swift
│   ├── CatalogDAOTests.swift
│   ├── DatabaseManagerTests.swift
│   └── HTTPRecorderTests.swift
```

---

## Phase 1: Foundation Layer

### Task 1: Add test target to TunnelServices Package.swift

**Files:**
- Modify: `LocalPackages/TunnelServices/Package.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/StorageTestHelper.swift`

- [ ] **Step 1: Add test target to Package.swift**

Add to the `targets` array in Package.swift:

```swift
.testTarget(
    name: "TunnelServicesTests",
    dependencies: ["TunnelServices"],
    path: "Tests/TunnelServicesTests"
),
```

- [ ] **Step 2: Create test helper with temp directory utilities**

Create `Tests/TunnelServicesTests/StorageTestHelper.swift`:

```swift
import Foundation
import SQLite
@testable import TunnelServices

/// Provides temp directories and cleanup for storage tests
class StorageTestHelper {
    let tempDir: String

    init() {
        tempDir = NSTemporaryDirectory() + "KnotTests_\(UUID().uuidString)"
        try! FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    func createTempDB(name: String = "test.db") throws -> Connection {
        let path = (tempDir as NSString).appendingPathComponent(name)
        return try Connection(path)
    }
}
```

- [ ] **Step 3: Verify test target builds**

Run: `cd /Users/aa123/Documents/Knot && xcodebuild test -project Knot.xcodeproj -scheme TunnelServicesTests -destination 'platform=macOS' 2>&1 | tail -20`

Note: `swift test` may not work due to platform-conditional dependencies (SwiftQuiche/SwiftLsquic are iOS-only). If that happens, use `xcodebuild test` with the Xcode project. Alternatively, add `condition: .when(platforms: [.macOS, .iOS])` to the test target and exclude QUIC-dependent code.

- [ ] **Step 4: Commit**

```bash
git add LocalPackages/TunnelServices/Package.swift LocalPackages/TunnelServices/Tests/
git commit -m "feat(storage): add test target to TunnelServices package"
```

---

### Task 2: PathManager

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/PathManager.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/PathManagerTests.swift`

- [ ] **Step 1: Write PathManager tests**

Test: path computation correctness, directory creation, all path variants.

```swift
import XCTest
@testable import TunnelServices

final class PathManagerTests: XCTestCase {
    var helper: StorageTestHelper!

    override func setUp() { helper = StorageTestHelper() }
    override func tearDown() { helper = nil }

    func testTaskDirectory() {
        let path = PathManager.taskDirectory(42, root: helper.tempDir)
        XCTAssertEqual(path, "\(helper.tempDir)/tasks/42")
    }

    func testTransportDBPath() {
        let path = PathManager.transportDBPath(42, root: helper.tempDir)
        XCTAssertTrue(path.hasSuffix("/tasks/42/transport.db"))
    }

    func testRawPayloadPath() {
        let path = PathManager.rawPayloadPath(taskId: 1, ref: "123_0001_req.bin", root: helper.tempDir)
        XCTAssertTrue(path.hasSuffix("/tasks/1/payloads/raw/123_0001_req.bin"))
    }

    func testDecodedPayloadPath() {
        let path = PathManager.decodedPayloadPath(taskId: 1, flowId: "123_0001", direction: .request, ext: "json", root: helper.tempDir)
        XCTAssertTrue(path.hasSuffix("/tasks/1/payloads/decoded/123_0001_req.json"))
    }

    func testModifiedPayloadPath() {
        let path = PathManager.modifiedPayloadPath(taskId: 1, flowId: "123_0001", version: 2, direction: .response, root: helper.tempDir)
        XCTAssertTrue(path.hasSuffix("/tasks/1/payloads/modified/123_0001_v2_rsp.bin"))
    }

    func testEnsureTaskDirectories() throws {
        try PathManager.ensureTaskDirectories(99, root: helper.tempDir)
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: "\(helper.tempDir)/tasks/99/payloads/raw"))
        XCTAssertTrue(fm.fileExists(atPath: "\(helper.tempDir)/tasks/99/payloads/decoded"))
        XCTAssertTrue(fm.fileExists(atPath: "\(helper.tempDir)/tasks/99/payloads/modified"))
        XCTAssertTrue(fm.fileExists(atPath: "\(helper.tempDir)/tasks/99/export"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PathManagerTests 2>&1 | tail -10`

- [ ] **Step 3: Implement PathManager**

Create `Storage/PathManager.swift` per spec (lines 738-751). All methods accept an optional `root` parameter (defaults to App Group container) to enable testing with temp directories.

Key: `PayloadDirection` enum (`.request`, `.response`) defined here.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/PathManager.swift \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/PathManagerTests.swift
git commit -m "feat(storage): add PathManager for unified file path management"
```

---

### Task 3: FlowIdGenerator

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/FlowIdGenerator.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/FlowIdGeneratorTests.swift`

- [ ] **Step 1: Write FlowIdGenerator tests**

```swift
final class FlowIdGeneratorTests: XCTestCase {
    func testUniqueIds() {
        let gen = FlowIdGenerator()
        var ids = Set<String>()
        for _ in 0..<1000 {
            ids.insert(gen.next())
        }
        XCTAssertEqual(ids.count, 1000, "All IDs should be unique")
    }

    func testFormat() {
        let gen = FlowIdGenerator()
        let id = gen.next()
        let parts = id.split(separator: "_")
        XCTAssertEqual(parts.count, 2)
        XCTAssertNotNil(Int64(parts[0]))
        XCTAssertEqual(parts[1].count, 4)  // zero-padded 4 digits
    }

    func testThreadSafety() {
        let gen = FlowIdGenerator()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        var allIds: [String] = []
        let lock = NSLock()

        for _ in 0..<100 {
            group.enter()
            queue.async {
                let id = gen.next()
                lock.lock()
                allIds.append(id)
                lock.unlock()
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(Set(allIds).count, 100)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement FlowIdGenerator**

Per spec lines 618-636. NSLock-based, millisecond timestamp + 4-digit sequence.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/FlowIdGenerator.swift \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/FlowIdGeneratorTests.swift
git commit -m "feat(storage): add thread-safe FlowIdGenerator"
```

---

### Task 4: Database Schema definitions

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Schema/CatalogSchema.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Schema/TransportSchema.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Schema/ProtocolSchema.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Schema/DecodedSchema.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Schema/StateSchema.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/SchemaTests.swift`

- [ ] **Step 1: Write schema tests**

Test that each schema's `create(db:)` method runs without error and creates the expected tables.

```swift
final class SchemaTests: XCTestCase {
    var helper: StorageTestHelper!
    override func setUp() { helper = StorageTestHelper() }
    override func tearDown() { helper = nil }

    func testCatalogSchema() throws {
        let db = try helper.createTempDB(name: "catalog.db")
        try CatalogSchema.create(db)
        // Verify tables exist by querying sqlite_master
        let tables = try db.prepare("SELECT name FROM sqlite_master WHERE type='table'").map { $0[0] as! String }
        XCTAssertTrue(tables.contains("capture_task"))
        XCTAssertTrue(tables.contains("rule"))
        XCTAssertTrue(tables.contains("breakpoint"))
    }

    func testTransportSchema() throws {
        let db = try helper.createTempDB(name: "transport.db")
        try TransportSchema.create(db)
        let tables = try db.prepare("SELECT name FROM sqlite_master WHERE type='table'").map { $0[0] as! String }
        XCTAssertTrue(tables.contains("packet"))
    }

    func testProtocolSchema() throws {
        let db = try helper.createTempDB(name: "protocol.db")
        try ProtocolSchema.create(db)
        let tables = try db.prepare("SELECT name FROM sqlite_master WHERE type='table'").map { $0[0] as! String }
        XCTAssertTrue(tables.contains("flow"))
    }

    func testDecodedSchema() throws {
        let db = try helper.createTempDB(name: "decoded.db")
        try DecodedSchema.create(db)
        let tables = try db.prepare("SELECT name FROM sqlite_master WHERE type='table' OR type='trigger'")
            .map { $0[0] as! String }
        XCTAssertTrue(tables.contains("decoded_entry"))
    }

    func testStateSchema() throws {
        let db = try helper.createTempDB(name: "state.db")
        try StateSchema.create(db)
        let tables = try db.prepare("SELECT name FROM sqlite_master WHERE type='table'").map { $0[0] as! String }
        XCTAssertTrue(tables.contains("connection"))
        XCTAssertTrue(tables.contains("modify_log"))
        XCTAssertTrue(tables.contains("task_stats"))
        // Verify task_stats singleton row was inserted
        let count = try db.scalar("SELECT COUNT(*) FROM task_stats") as! Int64
        XCTAssertEqual(count, 1)
    }

    func testIdempotent() throws {
        let db = try helper.createTempDB()
        try CatalogSchema.create(db)
        try CatalogSchema.create(db) // second call should not throw
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement all 5 schema files**

Each schema is an `enum` with a single `static func create(_ db: Connection) throws` method containing `CREATE TABLE IF NOT EXISTS` statements matching the spec SQL exactly. Use `db.execute()` for raw DDL.

- CatalogSchema: capture_task + rule + breakpoint tables + breakpoint index (spec lines 131-186)
- TransportSchema: packet table + indexes (spec lines 192-221)
- ProtocolSchema: flow table + indexes (spec lines 232-288)
- DecodedSchema: decoded_entry + FTS5 virtual table + triggers + index (spec lines 305-359)
- StateSchema: connection + modify_log + task_stats + indexes + singleton INSERT (spec lines 365-412)

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Schema/ \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/SchemaTests.swift
git commit -m "feat(storage): add database schema definitions for all 5 databases"
```

---

### Task 5: Model structs

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Model/FlowRecord.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Model/PacketRow.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Model/DecodedEntry.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Model/ConnectionRecord.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Model/ModifyLogEntry.swift`

- [ ] **Step 1: Create all model structs**

Plain Swift structs matching the spec. No ORM inheritance, no NSObject.

`FlowRecord.swift` (spec lines 691-719):
- `FlowStatus` enum: `.inProgress`, `.completed`, `.failed` (rawValue 0/1/2)
- `FlowRecord` struct with all fields
- `SearchKeyMapping` struct
- `PayloadDirection` enum already in PathManager — import from there

`PacketRow.swift`: matches transport.db packet table columns. Include a `static func stub(flowId: String) -> PacketRow` convenience factory for tests (fills sensible defaults for all fields).

`DecodedEntry.swift`: matches decoded.db decoded_entry columns. `DecodeResult` struct for decoder output.

`ConnectionRecord.swift`: matches state.db connection table.

`ModifyLogEntry.swift`: matches state.db modify_log table.

- [ ] **Step 2: Verify build**

Run: `swift build --target TunnelServices 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Model/
git commit -m "feat(storage): add model structs for all database tables"
```

---

### Task 6: DatabaseManager + TaskDatabaseGroup

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DatabaseManager.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/TaskDatabaseGroup.swift`

- [ ] **Step 1: Write integration tests first**

```swift
final class DatabaseManagerTests: XCTestCase {
    func testOpenAndCloseTask() throws {
        let helper = StorageTestHelper()
        let mgr = DatabaseManager(rootPath: helper.tempDir)
        let group = try mgr.openTask(1)
        // Verify all 4 DBs are accessible
        XCTAssertNoThrow(try group.proto.scalar("SELECT COUNT(*) FROM flow"))
        XCTAssertNoThrow(try group.transport.scalar("SELECT COUNT(*) FROM packet"))
        // Verify FlowIdGenerator is available
        let flowId = group.flowIdGenerator.next()
        XCTAssertFalse(flowId.isEmpty)
        mgr.closeTask(1)
    }

    func testDeleteTask() throws {
        let helper = StorageTestHelper()
        let mgr = DatabaseManager(rootPath: helper.tempDir)
        _ = try mgr.openTask(1)
        mgr.closeTask(1)
        try mgr.deleteTask(1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: PathManager.taskDirectory(1, root: helper.tempDir)))
    }

    func testRefCounting() throws {
        let helper = StorageTestHelper()
        let mgr = DatabaseManager(rootPath: helper.tempDir)
        let g1 = try mgr.openTask(1)
        let g2 = try mgr.openTask(1)  // same task, increments refCount
        XCTAssertTrue(g1 === g2)      // same instance
        mgr.closeTask(1)              // refCount 2 → 1, still open
        XCTAssertNoThrow(try g1.proto.scalar("SELECT COUNT(*) FROM flow"))
        mgr.closeTask(1)              // refCount 1 → 0, closed
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement TaskDatabaseGroup**

Per spec lines 537-550. Constructor:
1. Creates task directory via `PathManager.ensureTaskDirectories()`
2. Opens 4 `Connection` objects (transport/proto/decoded/state)
3. Configures PRAGMA on each (WAL, synchronous, cache_size, mmap_size, busy_timeout)
4. Calls each Schema's `create()` method
5. Creates 4 serial DispatchQueues
6. Creates a `FlowIdGenerator` instance (one per task)

Accept a `PragmaProfile` enum (`.mainApp`, `.packetTunnel`) to configure different PRAGMA values per spec lines 557-573.

`TaskDatabaseGroup` must be a `class` (reference type) so identity comparison (`===`) works for ref counting.

- [ ] **Step 4: Implement DatabaseManager**

Per spec lines 519-531. Accept `rootPath: String` in initializer for testability (default = `PathManager.root`).
- `catalogDB: Connection` initialized on `init()` with CatalogSchema
- `activePools: [Int64: TaskDatabaseGroup]` with NSLock + refCount
- `openTask(_:)`, `closeTask(_:)`, `deleteTask(_:)` methods

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DatabaseManager.swift \
       LocalPackages/TunnelServices/Sources/TunnelServices/Storage/TaskDatabaseGroup.swift \
       LocalPackages/TunnelServices/Tests/
git commit -m "feat(storage): add DatabaseManager and TaskDatabaseGroup with WAL config"
```

---

## Phase 2: Streaming I/O

### Task 7: PayloadWriter

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/PayloadWriter.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/PayloadWriterTests.swift`

- [ ] **Step 1: Write tests**

```swift
final class PayloadWriterTests: XCTestCase {
    var helper: StorageTestHelper!
    override func setUp() { helper = StorageTestHelper() }
    override func tearDown() { helper = nil }

    func testWriteAndReadBack() throws {
        let writer = try PayloadWriter(directory: helper.tempDir, fileName: "test.bin")
        let testData = Data(repeating: 0xAB, count: 1024)
        try writer.append(testData)
        try writer.close()

        let readBack = try Data(contentsOf: URL(fileURLWithPath: "\(helper.tempDir)/test.bin"))
        XCTAssertEqual(readBack, testData)
        XCTAssertEqual(writer.totalBytesWritten, 1024)
    }

    func testBufferingFlushesAtThreshold() throws {
        let writer = try PayloadWriter(directory: helper.tempDir, fileName: "test.bin", flushThreshold: 100)
        // Write 50 bytes — should be buffered, not yet on disk
        try writer.append(Data(repeating: 0x01, count: 50))
        let size1 = try FileManager.default.attributesOfItem(atPath: "\(helper.tempDir)/test.bin")[.size] as! Int
        XCTAssertEqual(size1, 0) // still buffered

        // Write 60 more — total 110, exceeds threshold, should flush
        try writer.append(Data(repeating: 0x02, count: 60))
        let size2 = try FileManager.default.attributesOfItem(atPath: "\(helper.tempDir)/test.bin")[.size] as! Int
        XCTAssertEqual(size2, 110)

        try writer.close()
    }

    func testCloseFlushesRemainingBuffer() throws {
        let writer = try PayloadWriter(directory: helper.tempDir, fileName: "test.bin", flushThreshold: 1024)
        try writer.append(Data(repeating: 0xFF, count: 10))
        try writer.close()
        let size = try FileManager.default.attributesOfItem(atPath: "\(helper.tempDir)/test.bin")[.size] as! Int
        XCTAssertEqual(size, 10)
    }

    func testLargeWrite() throws {
        let writer = try PayloadWriter(directory: helper.tempDir, fileName: "large.bin")
        let chunk = Data(repeating: 0xCD, count: 8192)
        for _ in 0..<100 { try writer.append(chunk) } // 800KB total
        try writer.close()
        XCTAssertEqual(writer.totalBytesWritten, 819200)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement PayloadWriter**

Per spec lines 424-441. 32KB default buffer. `append()` accepts `Data` (and a convenience overload for `ByteBuffer`). `flush()` writes buffer to FileHandle. `close()` flushes + closes handle. `removeAll(keepingCapacity: true)` on buffer after flush.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/PayloadWriter.swift \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/PayloadWriterTests.swift
git commit -m "feat(storage): add streaming PayloadWriter with configurable buffer"
```

---

### Task 8: PayloadReader

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/PayloadReader.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/PayloadReaderTests.swift`

- [ ] **Step 1: Write tests**

Test: `read(offset:length:)` range reads, `chunks()` iteration, `size` property, reading a file larger than chunkSize.

```swift
final class PayloadReaderTests: XCTestCase {
    var helper: StorageTestHelper!
    var testFilePath: String!

    override func setUp() {
        helper = StorageTestHelper()
        testFilePath = "\(helper.tempDir)/test_read.bin"
        // Write a known 256-byte file: 0x00, 0x01, ..., 0xFF
        var data = Data()
        for i: UInt8 in 0...255 { data.append(i) }
        FileManager.default.createFile(atPath: testFilePath, contents: data)
    }
    override func tearDown() { helper = nil }

    func testSize() throws {
        let reader = try PayloadReader(filePath: testFilePath)
        XCTAssertEqual(reader.size, 256)
        reader.close()
    }

    func testRangeRead() throws {
        let reader = try PayloadReader(filePath: testFilePath)
        let chunk = reader.read(offset: 10, length: 5)
        XCTAssertEqual(chunk, Data([10, 11, 12, 13, 14]))
        reader.close()
    }

    func testChunksIteration() throws {
        let reader = try PayloadReader(filePath: testFilePath, chunkSize: 100)
        var totalBytes = 0
        for chunk in reader.chunks() {
            totalBytes += chunk.count
        }
        XCTAssertEqual(totalBytes, 256)
        reader.close()
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement PayloadReader**

Per spec lines 454-465. `ChunkSequence` conforming to `Sequence`, `ChunkIterator` conforming to `IteratorProtocol`.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/PayloadReader.swift \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/PayloadReaderTests.swift
git commit -m "feat(storage): add streaming PayloadReader with chunk iteration"
```

---

### Task 9: TextAccumulator

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/TextAccumulator.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/TextAccumulatorTests.swift`

- [ ] **Step 1: Write tests**

```swift
final class TextAccumulatorTests: XCTestCase {
    func testAccumulatesText() {
        let acc = TextAccumulator(maxSize: 1024)
        acc.append(Data("Hello ".utf8))
        acc.append(Data("World".utf8))
        XCTAssertEqual(acc.text, "Hello World")
    }

    func testRespectsMaxSize() {
        let acc = TextAccumulator(maxSize: 10)
        acc.append(Data("1234567890EXTRA".utf8))
        XCTAssertEqual(acc.text?.count, 10)
    }

    func testReturnsNilForBinaryData() {
        let acc = TextAccumulator(maxSize: 1024)
        acc.append(Data([0xFF, 0xFE, 0x00, 0x80]))
        // Invalid UTF-8 should return nil
        XCTAssertNil(acc.text)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement TextAccumulator**

Per spec. Appends bytes up to `maxSize`, then stops. `text` property attempts UTF-8 decode, returns nil if invalid.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/TextAccumulator.swift \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/TextAccumulatorTests.swift
git commit -m "feat(storage): add TextAccumulator for bounded text extraction"
```

---

### Task 10: DecompressStream + PayloadDecoder

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/DecompressStream.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/PayloadDecoder.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/PayloadDecoderTests.swift`

- [ ] **Step 1: Write tests**

```swift
final class PayloadDecoderTests: XCTestCase {
    var helper: StorageTestHelper!
    override func setUp() { helper = StorageTestHelper() }
    override func tearDown() { helper = nil }

    func testDecodeIdentity() throws {
        // Write uncompressed text file
        let rawPath = "\(helper.tempDir)/raw.bin"
        let decodedPath = "\(helper.tempDir)/decoded.bin"
        try Data("Hello, World!".utf8).write(to: URL(fileURLWithPath: rawPath))

        let result = try PayloadDecoder.decode(rawPath: rawPath, decodedPath: decodedPath, encoding: "identity")
        XCTAssertEqual(result.decodedSize, 13)
        XCTAssertEqual(result.searchText, "Hello, World!")

        let decoded = try Data(contentsOf: URL(fileURLWithPath: decodedPath))
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "Hello, World!")
    }

    func testDecodeGzip() throws {
        let rawPath = "\(helper.tempDir)/raw.gz"
        let decodedPath = "\(helper.tempDir)/decoded.txt"
        let original = "Test data for gzip compression"
        // Write gzipped data
        let compressed = try (Data(original.utf8) as NSData).compressed(using: .zlib) as Data
        try compressed.write(to: URL(fileURLWithPath: rawPath))

        let result = try PayloadDecoder.decode(rawPath: rawPath, decodedPath: decodedPath, encoding: "deflate")
        XCTAssertEqual(result.searchText, original)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement DecompressStream**

`DecompressStream` protocol + `CompressionDecompressStream` class wrapping Apple's `compression_stream` API. `IdentityStream` passthrough for uncompressed data. Factory function `makeDecompressStream(encoding:)`.

- [ ] **Step 4: Implement PayloadDecoder**

`decode(rawPath:decodedPath:encoding:chunkSize:)` — reads via `PayloadReader`, pipes through `DecompressStream`, writes via `PayloadWriter`, accumulates text via `TextAccumulator`. Returns `DecodeResult`.

`decodeSynchronously(data:encoding:)` — in-memory version for intercept path.

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Payload/ \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/PayloadDecoderTests.swift
git commit -m "feat(storage): add streaming PayloadDecoder with compression support"
```

---

## Phase 3: Data Access Layer

### Task 11: FlowDAO

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/FlowDAO.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/FlowDAOTests.swift`

- [ ] **Step 1: Write tests**

Test insert, update, query with filters (protocol, host, searchKey), pagination.

```swift
final class FlowDAOTests: XCTestCase {
    var db: Connection!
    var helper: StorageTestHelper!

    override func setUp() throws {
        helper = StorageTestHelper()
        db = try helper.createTempDB(name: "protocol.db")
        try ProtocolSchema.create(db)
    }
    override func tearDown() { helper = nil }

    func testInsertAndFind() throws {
        var record = FlowRecord(flowId: "test_0001", protocolName: "HTTP", host: "example.com", port: 443, startedAt: Date().timeIntervalSince1970)
        record.searchKey1 = "GET"
        record.searchKey2 = "/api/users"
        record.searchKey3 = "200"
        record.summary = "GET /api/users → 200"
        try FlowDAO.insert(db: db, record: record)

        let results = try FlowDAO.query(db: db)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].host, "example.com")
        XCTAssertEqual(results[0].searchKey1, "GET")
    }

    func testUpdateFields() throws {
        var record = FlowRecord(flowId: "test_0001", protocolName: "HTTP", host: "example.com", port: 80, startedAt: 1000)
        try FlowDAO.insert(db: db, record: record)

        try FlowDAO.update(db: db, flowId: "test_0001", fields: [
            "endedAt": 2000.0,
            "status": FlowStatus.completed.rawValue,
            "summary": "GET / → 200",
            "downloadBytes": Int64(4096)
        ])

        let results = try FlowDAO.query(db: db)
        XCTAssertEqual(results[0].status, .completed)
        XCTAssertEqual(results[0].downloadBytes, 4096)
    }

    func testQueryWithFilters() throws {
        // Insert multiple records with different protocols
        for i in 0..<10 {
            var r = FlowRecord(flowId: "f_\(i)", protocolName: i < 5 ? "HTTP" : "DNS", host: "host\(i).com", port: 80, startedAt: Double(i))
            r.searchKey1 = i < 5 ? "GET" : "A"
            try FlowDAO.insert(db: db, record: r)
        }

        let httpOnly = try FlowDAO.query(db: db, protocol: "HTTP")
        XCTAssertEqual(httpOnly.count, 5)

        let paginated = try FlowDAO.query(db: db, offset: 0, limit: 3)
        XCTAssertEqual(paginated.count, 3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement FlowDAO**

`enum FlowDAO` with:
- `insert(db:record:)` — builds INSERT using SQLite.swift type-safe API. Serialize `metadata` to JSON string via `JSONSerialization`.
- `update(db:flowId:fields:)` — dynamic UPDATE builder.
- `query(db:protocol:hostContains:searchKeyFilters:offset:limit:)` — SELECT with optional WHERE clauses, ORDER BY started_at DESC.
- `find(db:flowId:)` — single record lookup.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/FlowDAO.swift \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/FlowDAOTests.swift
git commit -m "feat(storage): add FlowDAO for protocol.db CRUD operations"
```

---

### Task 12: PacketDAO + BatchWriter

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/PacketDAO.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/BatchWriter.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/BatchWriterTests.swift`

- [ ] **Step 1: Write tests**

```swift
final class BatchWriterTests: XCTestCase {
    var helper: StorageTestHelper!
    var db: Connection!

    override func setUp() throws {
        helper = StorageTestHelper()
        db = try helper.createTempDB(name: "transport.db")
        try TransportSchema.create(db)
    }
    override func tearDown() { helper = nil }

    func testBatchFlushOnSize() throws {
        let queue = DispatchQueue(label: "test.batch")
        let writer = BatchWriter(db: db, queue: queue, batchSize: 5, flushInterval: 10.0)

        for i in 0..<5 {
            writer.enqueue(PacketRow.stub(flowId: "flow_\(i)"))
        }

        // Wait for queue to process
        queue.sync {}
        Thread.sleep(forTimeInterval: 0.1)

        let count = try db.scalar("SELECT COUNT(*) FROM packet") as! Int64
        XCTAssertEqual(count, 5)

        writer.finalize()
    }

    func testFinalizeFlushesRemaining() throws {
        let queue = DispatchQueue(label: "test.batch")
        let writer = BatchWriter(db: db, queue: queue, batchSize: 100, flushInterval: 10.0)

        writer.enqueue(PacketRow.stub(flowId: "flow_1"))
        writer.enqueue(PacketRow.stub(flowId: "flow_2"))
        writer.finalize()

        let count = try db.scalar("SELECT COUNT(*) FROM packet") as! Int64
        XCTAssertEqual(count, 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement PacketDAO**

`enum PacketDAO` with `insert(db:row:)` for single insert and `insertBatch(db:rows:)` for transaction-wrapped batch.

- [ ] **Step 4: Implement BatchWriter**

Per spec lines 590-599. Serial DispatchQueue, `pendingRows` array, `batchSize` threshold, `flushInterval` timer via `DispatchSourceTimer`, `flush()` wraps in transaction, `finalize()` does `queue.sync { flush() }`.

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/PacketDAO.swift \
       LocalPackages/TunnelServices/Sources/TunnelServices/Storage/BatchWriter.swift \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/BatchWriterTests.swift
git commit -m "feat(storage): add PacketDAO and BatchWriter for transport.db"
```

---

### Task 13: Remaining DAOs (DecodedEntry, Connection, ModifyLog, TaskStats, Catalog)

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/DecodedEntryDAO.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/ConnectionDAO.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/ModifyLogDAO.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/TaskStatsDAO.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/CatalogDAO.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/DecodedEntryDAOTests.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/CatalogDAOTests.swift`

- [ ] **Step 1: Write DecodedEntryDAO tests**

```swift
final class DecodedEntryDAOTests: XCTestCase {
    var db: Connection!
    var helper: StorageTestHelper!

    override func setUp() throws {
        helper = StorageTestHelper()
        db = try helper.createTempDB(name: "decoded.db")
        try DecodedSchema.create(db)
    }
    override func tearDown() { helper = nil }

    func testInsertAndFind() throws {
        let entry = DecodedEntry(flowId: "f_001", direction: 1, originalEncoding: "gzip",
            decodedType: "text/html", decodedSize: 100, payloadRef: "f_001_rsp.html",
            isInline: false, inlineData: nil, searchText: "Hello World", decodedAt: 1000, sequence: 0)
        try DecodedEntryDAO.insert(db: db, entry: entry)
        let found = try DecodedEntryDAO.find(db: db, flowId: "f_001", direction: 1)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.decodedType, "text/html")
    }

    func testInlineSmallPayload() throws {
        let smallData = Data("tiny".utf8)
        let entry = DecodedEntry(flowId: "f_002", direction: 0, originalEncoding: "identity",
            decodedType: "text/plain", decodedSize: Int64(smallData.count), payloadRef: "",
            isInline: true, inlineData: smallData, searchText: "tiny", decodedAt: 1000, sequence: 0)
        try DecodedEntryDAO.insert(db: db, entry: entry)
        let found = try DecodedEntryDAO.find(db: db, flowId: "f_002", direction: 0)
        XCTAssertEqual(found?.isInline, true)
        XCTAssertEqual(found?.inlineData, smallData)
    }

    func testFTSSearch() throws {
        let entry1 = DecodedEntry(flowId: "f_010", direction: 1, decodedType: "text/html",
            decodedSize: 50, searchText: "login page with username field", decodedAt: 1000)
        let entry2 = DecodedEntry(flowId: "f_011", direction: 1, decodedType: "application/json",
            decodedSize: 30, searchText: "api response with token", decodedAt: 1001)
        try DecodedEntryDAO.insert(db: db, entry: entry1)
        try DecodedEntryDAO.insert(db: db, entry: entry2)

        let results = try DecodedEntryDAO.searchFullText(db: db, query: "username", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].flowId, "f_010")
    }
}
```

- [ ] **Step 2: Write CatalogDAO tests**

```swift
final class CatalogDAOTests: XCTestCase {
    var db: Connection!
    var helper: StorageTestHelper!

    override func setUp() throws {
        helper = StorageTestHelper()
        db = try helper.createTempDB(name: "catalog.db")
        try CatalogSchema.create(db)
    }
    override func tearDown() { helper = nil }

    func testInsertAndFindTask() throws {
        let taskId = try CatalogDAO.insertTask(db: db, name: "Test", createdAt: 1000)
        XCTAssertGreaterThan(taskId, 0)
        let tasks = try CatalogDAO.findAllTasks(db: db)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].name, "Test")
    }

    func testInsertAndFindBreakpoint() throws {
        try CatalogDAO.insertBreakpoint(db: db, matchPattern: "*.example.com", action: "pause", createdAt: 1000)
        let bps = try CatalogDAO.findEnabledBreakpoints(db: db)
        XCTAssertEqual(bps.count, 1)
        XCTAssertEqual(bps[0].matchPattern, "*.example.com")
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

- [ ] **Step 4: Implement DecodedEntryDAO**

- `insert(db:entry:)` — handles inline vs file-ref logic (is_inline = decodedSize <= 4096)
- `find(db:flowId:direction:)` — lookup
- `searchFullText(db:query:limit:)` — FTS5 search via `decoded_fts`

- [ ] **Step 5: Implement ConnectionDAO**

- `insertOrUpdate(db:record:)` — UPSERT on flow_id
- `find(db:flowId:)` — lookup
- `updateState(db:flowId:clientState:serverState:closedAt:closeReason:)`

- [ ] **Step 6: Implement ModifyLogDAO**

- `insert(db:entry:)` — append-only
- `findAll(db:flowId:)` — history for a flow

- [ ] **Step 7: Implement TaskStatsDAO**

- `update(db:stats:)` — UPDATE the singleton row
- `read(db:)` — read current stats

- [ ] **Step 8: Implement CatalogDAO**

- `insertTask(db:task:)`, `updateTask(db:taskId:fields:)`, `findAllTasks(db:)`, `deleteTask(db:taskId:)`
- `insertRule(db:rule:)`, `findAllRules(db:)`, `findRule(db:id:)`
- `insertBreakpoint(db:bp:)`, `findEnabledBreakpoints(db:)`, `updateBreakpoint(db:id:enabled:)`

- [ ] **Step 9: Run tests to verify they pass**

- [ ] **Step 10: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DAO/
git commit -m "feat(storage): add DAOs for decoded, state, and catalog databases"
```

---

## Phase 4: Orchestration

### Task 14: DecodeScheduler

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DecodeScheduler.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/DecodeSchedulerTests.swift`

- [ ] **Step 1: Write tests**

```swift
final class DecodeSchedulerTests: XCTestCase {
    var helper: StorageTestHelper!

    override func setUp() { helper = StorageTestHelper() }
    override func tearDown() { helper = nil }

    func testAsyncDecodeProcessesQueue() throws {
        let mgr = DatabaseManager(rootPath: helper.tempDir)
        let group = try mgr.openTask(1)
        let scheduler = DecodeScheduler(dbGroup: group, rootPath: helper.tempDir)

        // Insert a flow with a raw payload
        var record = FlowRecord(flowId: "test_0001", protocolName: "HTTP", host: "test.com", port: 80, startedAt: 1000)
        record.rspPayloadRef = "test_0001_rsp.bin"
        record.metadata = ["rspEncoding": "identity"]
        try FlowDAO.insert(db: group.proto, record: record)

        // Write raw payload
        let rawDir = "\(helper.tempDir)/tasks/1/payloads/raw"
        try Data("decoded content".utf8).write(to: URL(fileURLWithPath: "\(rawDir)/test_0001_rsp.bin"))

        // Enqueue async decode
        scheduler.enqueueAsync(flowId: "test_0001")

        // Wait for processing
        let expectation = expectation(description: "decode")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { expectation.fulfill() }
        wait(for: [expectation], timeout: 3.0)

        // Verify decoded entry was created
        let entries = try DecodedEntryDAO.find(db: group.decoded, flowId: "test_0001", direction: 1)
        XCTAssertNotNil(entries)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement DecodeScheduler**

Per spec lines 646-653:
- `enqueueAsync(flowId:)` — adds to serial decode queue, processes FIFO
- `decodeSynchronously(flowId:eventLoop:)` — returns `EventLoopFuture<DecodedPayload>`, executes on decode queue, fulfills promise
- Shared `decodeFlow(flowId:)` method:
  1. Read flow metadata from `protocol.db` via `FlowDAO.find()`
  2. Extract encoding from metadata JSON
  3. Call `PayloadDecoder.decode()` for req and rsp
  4. Write result to `decoded.db` via `DecodedEntryDAO.insert()`

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/DecodeScheduler.swift \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/DecodeSchedulerTests.swift
git commit -m "feat(storage): add DecodeScheduler with async and sync decode paths"
```

---

### Task 15: TaskStatsSync

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/TaskStatsSync.swift`

- [ ] **Step 1: Implement TaskStatsSync**

Per spec lines 604-611:
- `start(taskId:)` — creates 5-second repeating `DispatchSourceTimer`
- Timer reads `task_stats` from `state.db`, writes snapshot to `catalog.db` via `CatalogDAO.updateTask()`
- `syncNow()` — immediate sync (called on capture stop)
- `stop()` — cancels timer, does final sync
- `recoverCrashedTasks(catalogDB:)` — static method called on App launch, finds `status=running` tasks, does sync

- [ ] **Step 2: Verify build**

- [ ] **Step 3: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/TaskStatsSync.swift
git commit -m "feat(storage): add TaskStatsSync for periodic catalog.db updates"
```

---

## Phase 5: Protocol Integration

### Task 16: ProtocolRecorder interface + HTTPRecorder

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Protocol/ProtocolRecorder.swift`
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Protocol/HTTPRecorder.swift`
- Create: `LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/HTTPRecorderTests.swift`

- [ ] **Step 1: Write tests**

```swift
final class HTTPRecorderTests: XCTestCase {
    func testBuildFlowRecord() {
        let recorder = HTTPRecorder(flowId: "test_0001", task: nil)
        recorder.recordRequestHead(method: "POST", uri: "/api/data", host: "api.example.com", port: 443, headers: [("Content-Type", "application/json")])
        recorder.recordResponseHead(statusCode: 201, headers: [("Content-Type", "application/json")])

        let record = recorder.buildFlowRecord()
        XCTAssertEqual(record.protocolName, "HTTP")
        XCTAssertEqual(record.host, "api.example.com")
        XCTAssertEqual(record.searchKey1, "POST")
        XCTAssertEqual(record.searchKey2, "/api/data")
        XCTAssertEqual(record.searchKey3, "201")
        XCTAssertEqual(record.searchKey4, "application/json")
        XCTAssertEqual(record.summary, "POST /api/data → 201")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement ProtocolRecorder protocol**

```swift
protocol ProtocolRecorder: AnyObject {
    static var protocolName: String { get }
    static var searchKeyMapping: SearchKeyMapping { get }
    func buildFlowRecord() -> FlowRecord
}
```

- [ ] **Step 4: Implement HTTPRecorder**

Implements `ProtocolRecorder`. Methods:
- `recordRequestHead(method:uri:host:port:headers:)` — stores request metadata
- `recordResponseHead(statusCode:headers:)` — stores response metadata
- `recordTimings(...)` — stores detailed timeline
- `buildFlowRecord()` — assembles `FlowRecord` with searchKey mappings per spec line 295

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Protocol/ \
       LocalPackages/TunnelServices/Tests/TunnelServicesTests/Storage/HTTPRecorderTests.swift
git commit -m "feat(storage): add ProtocolRecorder interface and HTTPRecorder"
```

---

### Task 17: Integrate with HTTPCaptureHandler (dual-write)

**Files:**
- Modify: `LocalPackages/TunnelServices/Sources/TunnelServices/Proxy/SessionRecorder.swift`
- Modify: `LocalPackages/TunnelServices/Sources/TunnelServices/Proxy/HTTPCaptureHandler.swift`

This is Phase 1 of the migration: **dual-write** — existing Session writes continue, new FlowRecord writes added alongside.

**Important:** The existing `CaptureTask.id` is `NSNumber?` (inherited from ASModel). Bridge to `Int64` via `task.id?.int64Value ?? 0`. The `FlowIdGenerator` lives on `TaskDatabaseGroup` (created in Task 6), NOT on `CaptureTask`.

- [ ] **Step 1: Add new storage properties to SessionRecorder**

Add to `SessionRecorder`:
```swift
// New storage system (dual-write)
private var httpRecorder: HTTPRecorder?
private var reqPayloadWriter: PayloadWriter?
private var rspPayloadWriter: PayloadWriter?
private var dbGroup: TaskDatabaseGroup?
private var taskId: Int64 = 0
```

- [ ] **Step 2: Initialize new storage in SessionRecorder.init**

After existing Session creation:
```swift
let taskId = task.id?.int64Value ?? 0
self.taskId = taskId
if let group = try? DatabaseManager.shared.openTask(taskId) {
    self.dbGroup = group
    let flowId = group.flowIdGenerator.next()  // FlowIdGenerator lives on TaskDatabaseGroup
    self.httpRecorder = HTTPRecorder(flowId: flowId, task: nil)
    // Create PayloadWriters for raw payloads
    let rawDir = "\(PathManager.payloadsDirectory(taskId))/raw"
    self.reqPayloadWriter = try? PayloadWriter(directory: rawDir, fileName: "\(flowId)_req.bin")
    self.rspPayloadWriter = try? PayloadWriter(directory: rawDir, fileName: "\(flowId)_rsp.bin")
}
```

- [ ] **Step 3: Add dual-write calls to recording methods**

In each existing `recordRequestHead()`, `recordRequestBody()`, `recordResponseHead()`, `recordResponseBody()`, `recordClosed()` — add corresponding calls to `httpRecorder` and `PayloadWriter`.

In `recordClosed()`:
```swift
// Flush and close payload writers
try? reqPayloadWriter?.close()
try? rspPayloadWriter?.close()

// Build and persist FlowRecord
if let recorder = httpRecorder, let group = dbGroup {
    var record = recorder.buildFlowRecord()
    record.reqPayloadRef = "\(record.flowId)_req.bin"
    record.rspPayloadRef = "\(record.flowId)_rsp.bin"
    group.protoWriteQueue.async {
        try? FlowDAO.insert(db: group.proto, record: record)
    }
    // Enqueue for background decode
    // decodeScheduler.enqueueAsync(flowId: record.flowId)
}
```

- [ ] **Step 4: Test manually** — start a capture, verify both old Session and new Flow data are written

- [ ] **Step 5: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Proxy/SessionRecorder.swift \
       LocalPackages/TunnelServices/Sources/TunnelServices/Proxy/HTTPCaptureHandler.swift
git commit -m "feat(storage): add dual-write to SessionRecorder for gradual migration"
```

---

## Phase 6: Migration

### Task 18: LegacyMigrator

**Files:**
- Create: `LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Migration/LegacyMigrator.swift`

- [ ] **Step 1: Implement LegacyMigrator**

Per spec lines 777-808:

```swift
enum LegacyMigrator {
    /// Migrates data from legacy nio.db to new multi-database architecture.
    /// Safe: backs up nio.db first, uses transactions, tracks progress for crash recovery.
    static func migrateIfNeeded(legacyDBPath: String, catalogDB: Connection, rootPath: String) throws {
        // 1. Check if migration already completed (migration_state in catalog.db)
        // 2. Backup nio.db → nio.db.bak
        // 3. Open legacy DB
        // 4. Migrate Rules → catalog.db rule table
        // 5. For each CaptureTask:
        //    a. Insert into catalog.db capture_task
        //    b. Open TaskDatabaseGroup
        //    c. Migrate all Sessions → protocol.db flow table (in transaction)
        //    d. Move body files → payloads/raw/
        //    e. Close TaskDatabaseGroup
        //    f. Record progress
        // 6. Mark migration complete
    }
}
```

Key field mappings per spec lines 791-808.

- [ ] **Step 2: Add migration call to app startup**

In `MitmService.prepare()` or `AppDelegate`, after initializing `DatabaseManager`:
```swift
if FileManager.default.fileExists(atPath: legacyDBPath) {
    try? LegacyMigrator.migrateIfNeeded(
        legacyDBPath: legacyDBPath,
        catalogDB: DatabaseManager.shared.catalogDB,
        rootPath: PathManager.root
    )
}
```

- [ ] **Step 3: Commit**

```bash
git add LocalPackages/TunnelServices/Sources/TunnelServices/Storage/Migration/
git commit -m "feat(storage): add LegacyMigrator for nio.db to new architecture"
```

---

## Post-Implementation Notes

### What this plan does NOT cover (future phases):

1. **Phase 2 of migration**: Switch UI layer from reading old Session to reading new FlowDAO. This requires changes to SwiftUI views in KnotUI package.
2. **Phase 3 of migration**: Remove ActiveSQLite framework and old models.
3. **PacketCaptureEngine integration**: Wiring transport.db writes into the VPN tunnel extension. This requires changes to the PacketTunnel target.
4. **Other ProtocolRecorders**: WebSocket, DNS, gRPC, MQTT recorders — follow the same pattern as HTTPRecorder.
5. **Breakpoint/script engine**: The full intercept → decode → modify → forward pipeline.

These are separate plans to be created after this foundation is stable and the dual-write is validated.
