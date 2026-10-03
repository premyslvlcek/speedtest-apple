//
//  HistoryTests.swift
//  HistoryFeatureTests
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@testable import HistoryFeature

/// The history lives in memory in tests (`defaultFileStorage`), and each test has its own.
@MainActor
@Suite(.mainSerialExecutor) struct HistoryTests {
    @Test func theLiveClientPutsANewRunFirst() {
        @Shared(.history) var entries = [Self.entry(Self.monday)]

        HistoryClient.live.save(Self.entry(Self.tuesday))

        #expect(entries.map(\.date) == [Self.tuesday, Self.monday])
    }

    @Test func deletingARowRemovesThatEntry() async {
        let store = Self.store(seeded: [Self.wednesday, Self.tuesday, Self.monday])

        await store.send(\.view.deleteTapped, IndexSet(integer: 1)) {
            $0.$entries.withLock { $0 = [Self.entry(Self.wednesday), Self.entry(Self.monday)] }
        }
    }

    @Test func clearAsksFirstThenDeletesEverything() async {
        let store = Self.store(seeded: [Self.tuesday, Self.monday])

        await store.send(\.view.clearTapped) {
            $0.alert = .clearAll
        }
        await store.send(\.alert.presented.clearAll) {
            $0.alert = nil
            $0.$entries.withLock { $0 = [] }
        }
    }

    @Test func doneDismissesTheSheet() async {
        let dismissed = LockIsolated(false)
        let store = Self.store(seeded: []) {
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(\.view.doneTapped)

        #expect(dismissed.value)
    }

    // MARK: - Support

    static let monday = Date(timeIntervalSince1970: 1_790_640_000)
    static let tuesday = monday.addingTimeInterval(86400)
    static let wednesday = tuesday.addingTimeInterval(86400)

    /// A store whose history holds one entry per date, in the given order (newest first).
    private static func store(
        seeded dates: [Date],
        dependencies: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<History> {
        @Shared(.history) var entries = dates.map(entry)
        return TestStore(initialState: History.State()) {
            History()
        } withDependencies: {
            dependencies(&$0)
        }
    }

    nonisolated static func entry(_ date: Date) -> HistoryEntry {
        HistoryEntry(
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
}
