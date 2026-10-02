//
//  HistoryClientLive.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import ComposableArchitecture
import SQLiteData

public extension HistoryClient {
    /// Inserts into the app's database, resolved when this value is created.
    static var live: HistoryClient {
        @Dependency(\.defaultDatabase) var database
        return HistoryClient(save: { entry in
            try await database.write { db in
                try HistoryEntry.insert { entry }.execute(db)
            }
        })
    }
}

public extension HistoryClient {
    /// Previews keep nothing: a preview's database has no history table.
    static var preview: HistoryClient {
        HistoryClient(save: { _ in })
    }
}

public extension DependencyValues {
    /// Opens and migrates the history database and makes it the app's database. `inMemory` keeps it in memory, for a
    /// launch that must not touch the saved history (the UI test).
    mutating func prepareHistory(inMemory: Bool) throws {
        defaultDatabase = try historyDatabase(inMemory: inMemory)
    }
}
