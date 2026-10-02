//
//  HistoryDatabase.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import SQLiteData

/// The app's database, migrated. On a device it's a file in Application Support; in tests and previews
/// SQLiteData gives each one its own temporary database.
public func historyDatabase() throws -> any DatabaseWriter {
    let database = try defaultDatabase()
    var migrator = DatabaseMigrator()
    #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
    #endif
    migrator.registerMigration("Create historyEntries") { db in
        try #sql(
            """
            CREATE TABLE "historyEntries"(
              "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              "date" TEXT NOT NULL,
              "serverProvider" TEXT NOT NULL,
              "serverCity" TEXT NOT NULL,
              "pingMilliseconds" REAL,
              "downloadMbps" REAL NOT NULL,
              "uploadMbps" REAL,
              "ipAddress" TEXT,
              "ipProvider" TEXT
            ) STRICT
            """
        )
        .execute(db)
    }
    try migrator.migrate(database)
    return database
}
