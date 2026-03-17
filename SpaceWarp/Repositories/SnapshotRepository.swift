//
//  SnapshotRepository.swift
//  SpaceWarp
//
//  Data persistence layer for snapshots.
//

import Foundation
import GRDB

// MARK: - SnapshotRepository

/// Handles persistence of snapshots to SQLite database.
final class SnapshotRepository {
    // MARK: - Properties
    
    private let dbQueue: DatabaseQueue
    
    // MARK: - Initialization
    
    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("SpaceWarp")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        
        let dbPath = dbDir.appendingPathComponent("SpaceWarp.db").path
        
        do {
            dbQueue = try DatabaseQueue(path: dbPath)
            try createTables()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Saves a snapshot to the database
    /// - Parameter snapshot: Snapshot to save
    func save(_ snapshot: Snapshot) async throws {
        try await dbQueue.write { db in
            let record = SnapshotRecord(snapshot)
            try record.insert(db)
        }
    }
    
    /// Updates an existing snapshot
    /// - Parameter snapshot: Snapshot to update
    func update(_ snapshot: Snapshot) async throws {
        try await dbQueue.write { db in
            let record = SnapshotRecord(snapshot)
            try record.update(db)
        }
    }
    
    /// Loads all snapshots
    /// - Returns: Array of snapshots
    func loadAll() async throws -> [Snapshot] {
        try await dbQueue.read { db in
            let records = try SnapshotRecord
                .filter(Column.isActive == true)
                .order(Column.createdAt.desc)
                .fetchAll(db)
            
            return records.map { $0.toSnapshot() }
        }
    }
    
    /// Loads a snapshot by ID
    /// - Parameter id: Snapshot ID
    /// - Returns: Snapshot if found
    func load(id: UUID) async throws -> Snapshot? {
        try await dbQueue.read { db in
            guard let record = try SnapshotRecord
                .filter(Column.id == id.uuidString)
                .filter(Column.isActive == true)
                .fetchOne(db) else {
                return nil
            }
            
            return record.toSnapshot()
        }
    }
    
    /// Loads a snapshot by name
    /// - Parameter name: Snapshot name
    /// - Returns: Snapshot if found
    func load(name: String) async throws -> Snapshot? {
        try await dbQueue.read { db in
            guard let record = try SnapshotRecord
                .filter(Column.name == name)
                .filter(Column.isActive == true)
                .fetchOne(db) else {
                return nil
            }
            
            return record.toSnapshot()
        }
    }
    
    /// Deletes a snapshot (soft delete)
    /// - Parameter snapshot: Snapshot to delete
    func delete(_ snapshot: Snapshot) async throws {
        try await dbQueue.write { db in
            try SnapshotRecord
                .filter(Column.id == snapshot.id.uuidString)
                .updateAll(db, Column.isActive.set(to: false))
        }
    }
    
    /// Permanently deletes a snapshot
    /// - Parameter snapshot: Snapshot to delete
    func permanentDelete(_ snapshot: Snapshot) async throws {
        try await dbQueue.write { db in
            _ = try SnapshotRecord
                .filter(Column.id == snapshot.id.uuidString)
                .deleteAll(db)
        }
    }
    
    /// Counts snapshots
    /// - Returns: Number of active snapshots
    func count() async throws -> Int {
        try await dbQueue.read { db in
            try SnapshotRecord
                .filter(Column.isActive == true)
                .fetchCount(db)
        }
    }
    
    // MARK: - Private Methods
    
    private func createTables() throws {
        try dbQueue.write { db in
            try db.create(table: "snapshots", ifNotExists: true) { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("description_text", .text).notNull().defaults(to: "")
                table.column("created_at", .datetime).notNull()
                table.column("windows_json", .text).notNull()
                table.column("displays_json", .text).notNull()
                table.column("metadata_json", .text)
                table.column("is_active", .boolean).notNull().defaults(to: true)
            }

            // Create indexes
            // Partial unique index: only enforce name uniqueness for active snapshots
            // This allows reusing names after soft-deleting a snapshot
            try db.create(index: "idx_snapshots_name_unique",
                          on: "snapshots",
                          columns: ["name"],
                          unique: true,
                          ifNotExists: true,
                          condition: Column.isActive == true)
            try db.create(index: "idx_snapshots_active", on: "snapshots", columns: ["is_active"], ifNotExists: true)
            try db.create(index: "idx_snapshots_created", on: "snapshots", columns: ["created_at"], ifNotExists: true)
        }
    }
}

// MARK: - SnapshotRecord

/// Database record for Snapshot
struct SnapshotRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "snapshots"
    
    // Column names match database schema
    var id: String
    var name: String
    var descriptionText: String  // Maps to description_text via CodingKeys
    var createdAt: Date
    var windowsJson: String
    var displaysJson: String
    var metadataJson: String?
    var isActive: Bool
    
    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case descriptionText = "description_text"
        case createdAt = "created_at"
        case windowsJson = "windows_json"
        case displaysJson = "displays_json"
        case metadataJson = "metadata_json"
        case isActive = "is_active"
    }
    
    // MARK: - Initialization
    
    init(_ snapshot: Snapshot) {
        self.id = snapshot.id.uuidString
        self.name = snapshot.name
        self.descriptionText = snapshot.description
        self.createdAt = snapshot.createdAt
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        self.windowsJson = (try? encoder.encode(snapshot.windows)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.displaysJson = (try? encoder.encode(snapshot.displays)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.metadataJson = (try? encoder.encode(snapshot.metadata)).flatMap { String(data: $0, encoding: .utf8) }
        self.isActive = true
    }
    
    func toSnapshot() -> Snapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let windows: [WindowInfo] = windowsJson.data(using: .utf8)
            .flatMap { try? decoder.decode([WindowInfo].self, from: $0) } ?? []
        
        let displays: [DisplayInfo] = displaysJson.data(using: .utf8)
            .flatMap { try? decoder.decode([DisplayInfo].self, from: $0) } ?? []
        
        let metadata: [String: String] = metadataJson?.data(using: .utf8)
            .flatMap { try? decoder.decode([String: String].self, from: $0) } ?? [:]
        
        return Snapshot(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            description: descriptionText,
            createdAt: createdAt,
            windows: windows,
            displays: displays,
            metadata: metadata
        )
    }
}

// MARK: - Column Definitions

extension Column {
    static let id = Column("id")
    static let name = Column("name")
    static let description = Column("description_text")
    static let createdAt = Column("created_at")
    static let windowsJson = Column("windows_json")
    static let displaysJson = Column("displays_json")
    static let metadataJson = Column("metadata_json")
    static let isActive = Column("is_active")
}
