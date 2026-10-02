//
//  HistoryTests.swift
//  HistoryFeatureTests
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing
import TestSupport

@testable import HistoryFeature

@MainActor
@Suite(.mainSerialExecutor) struct HistoryTests {
    @Test func entriesAreListedNewestFirst() async throws {
        let store = try await Self.store(seeded: [Self.monday, Self.wednesday, Self.tuesday])

        #expect(store.state.entries.map(\.date) == [Self.wednesday, Self.tuesday, Self.monday])
    }

    @Test func deletingARowRemovesThatEntry() async throws {
        let store = try await Self.store(seeded: [Self.monday, Self.tuesday, Self.wednesday])

        // Row 1 of the newest-first list is Tuesday's.
        await store.send(\.view.deleteTapped, IndexSet(integer: 1))
        try await store.state.$entries.load()

        #expect(store.state.entries.map(\.date) == [Self.wednesday, Self.monday])
    }

    @Test func clearAsksFirstThenDeletesEverything() async throws {
        let store = try await Self.store(seeded: [Self.monday, Self.tuesday])

        await store.send(\.view.clearTapped) {
            $0.confirmation = .clearAll
        }
        await store.send(\.confirmation.presented.clearAll) {
            $0.confirmation = nil
        }
        try await store.state.$entries.load()

        #expect(store.state.entries.isEmpty)
    }

    @Test func doneDismissesTheSheet() async throws {
        let dismissed = LockIsolated(false)
        let store = try await Self.store(seeded: []) {
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(\.view.doneTapped)

        #expect(dismissed.value)
    }

    // MARK: - Support

    static let monday = Date(timeIntervalSince1970: 1_790_640_000)
    static let tuesday = monday.addingTimeInterval(86400)
    static let wednesday = tuesday.addingTimeInterval(86400)

    /// A fresh, migrated database with one entry per date, and the list loaded from it.
    private static func store(
        seeded dates: [Date],
        dependencies: (inout DependencyValues) -> Void = { _ in }
    ) async throws -> TestStoreOf<History> {
        let database = try historyDatabase()
        try await database.write { db in
            for date in dates {
                try HistoryEntry.insert {
                    HistoryEntry.Draft(
                        recordedAt: date,
                        serverProvider: "jablonka.cz",
                        serverCity: "Prague",
                        pingMilliseconds: 6,
                        downloadMbps: 248,
                        uploadMbps: nil,
                        ipAddress: nil,
                        ipProvider: nil
                    )
                }
                .execute(db)
            }
        }
        let store = TestStore(initialState: History.State()) {
            History()
        } withDependencies: {
            $0.defaultDatabase = database
            dependencies(&$0)
        }
        try await store.state.$entries.load()
        return store
    }
}
