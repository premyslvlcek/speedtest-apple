//
//  SpeedTestTransferTests.swift
//  SpeedTestFeatureTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import Foundation
import ICMP
import SpeedTestKit
import SQLiteData
import Testing
import TestSupport

@testable import HistoryFeature
@testable import SpeedTestFeature

/// From the token to the end of the run: download, upload, failover and interruptions. Each test starts with the
/// server chosen; how the meter decides that a transfer failed or was interrupted is TransferMeter's (its tests).
@MainActor
@Suite(.mainSerialExecutor) struct SpeedTestTransferTests {
    typealias Start = RunFakes.Meter.Start

    let download1 = RunFakes.download1
    let download2 = RunFakes.download2
    let upload1 = RunFakes.upload1
    let token = RunFakes.token

    @Test func aRunMeasuresDownloadThenUploadOnTheSameServerWithTheSameToken() async throws {
        let meter = RunFakes.Meter([.samples([download1, download2]), .samples([upload1])])
        var state = try Self.serverChosen()
        state.selection?.ping = PingResult(rtts: [.milliseconds(6), .milliseconds(7), .milliseconds(5)], sent: 5)
        state.clientIP = Fixtures.clientIP
        let server = try #require(state.selection?.server)
        let store = try Self.store(state, meter)

        await store.send(.tokenResponse(.success(token))) {
            $0.token = token
        }
        await store.receive(\.sampled) {
            $0.downloadSamples = [download1]
            $0.phase = .downloading
        }
        await store.receive(\.sampled) {
            $0.downloadSamples = [download1, download2]
        }
        await store.receive(\.transferResponse) {
            $0.download = TransferResult(lastSample: download2, wasPartial: false)
            $0.phase = .connecting(.upload)
        }
        await store.receive(\.sampled) {
            $0.uploadSamples = [upload1]
            $0.phase = .uploading
        }
        await store.receive(\.transferResponse) {
            $0.upload = TransferResult(lastSample: upload1, wasPartial: false)
            $0.phase = .finished
        }

        #expect(meter.starts.value == [
            Start(server: server.id, direction: .download, token: token.value),
            Start(server: server.id, direction: .upload, token: token.value)
        ])
        #expect(try await Self.history(store) == [
            HistoryEntry(
                id: 1,
                date: Self.now,
                serverProvider: server.provider,
                serverCity: server.city,
                pingMilliseconds: 6,
                downloadMbps: download2.averageMbps,
                uploadMbps: upload1.averageMbps,
                ipAddress: Fixtures.clientIP.address,
                ipProvider: Fixtures.clientIP.provider
            )
        ])
    }

    /// The brief's test: download only. Upload is an opt-in extra.
    @Test func withUploadOffTheRunEndsAfterTheDownload() async throws {
        let meter = RunFakes.Meter([.samples([download1])])
        let store = try Self.store(Self.serverChosen(measuresUpload: false), meter)

        await store.send(.tokenResponse(.success(token))) {
            $0.token = token
        }
        await store.receive(\.sampled) {
            $0.downloadSamples = [download1]
            $0.phase = .downloading
        }
        await store.receive(\.transferResponse) {
            $0.download = TransferResult(lastSample: download1, wasPartial: false)
            $0.phase = .finished
        }

        #expect(meter.starts.value.map(\.direction) == [.download])
        #expect(try await Self.history(store).map(\.uploadMbps) == [nil])
    }

    /// The chosen server sends nothing: the run moves to the failover target, another host, and carries on there.
    @Test func aServerThatNeverStartsIsReplacedByTheFailoverTarget() async throws {
        let meter = RunFakes.Meter([.samples([], then: .transferFailed), .samples([download1]), .samples([upload1])])
        let state = try Self.serverChosen()
        let target = try #require(ServerSelector.failoverTarget(after: state.order[0], in: state.order))
        let store = try Self.store(state, meter)

        await store.send(.tokenResponse(.success(token))) {
            $0.token = token
        }
        await store.receive(\.transferResponse) {
            $0.selection = SpeedTest.Selection(server: target.server, ping: target.pingResult, reason: .failover)
            $0.hasFailedOver = true
        }
        await store.receive(\.sampled) {
            $0.downloadSamples = [download1]
            $0.phase = .downloading
        }
        await store.receive(\.transferResponse) {
            $0.download = TransferResult(lastSample: download1, wasPartial: false)
            $0.phase = .connecting(.upload)
        }
        await store.receive(\.sampled) {
            $0.uploadSamples = [upload1]
            $0.phase = .uploading
        }
        await store.receive(\.transferResponse) {
            $0.upload = TransferResult(lastSample: upload1, wasPartial: false)
            $0.phase = .finished
        }

        #expect(meter.starts.value.map(\.server) == [state.order[0].id, target.id, target.id])
    }

    @Test func failoverHappensOnlyOnce() async throws {
        let meter = RunFakes.Meter([.samples([], then: .transferFailed), .samples([], then: .transferFailed)])
        // One more host after the failover target, so a second failover would have somewhere to go.
        var state = try Self.serverChosen()
        let another = try #require(Fixtures.candidates.first { $0.server.provider == "Ubiquiti" })
        state.candidates.append(another)
        state.order.append(another)
        let store = try Self.store(state, meter)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tokenResponse(.success(token)))
        await store.receive(\.transferResponse)
        await store.receive(\.transferResponse)

        #expect(store.state.phase == .failed(.transferFailed))
        #expect(meter.starts.value.count == 2)
    }

    @Test func anOfflineDeviceFailsWithoutFailover() async throws {
        let meter = RunFakes.Meter([.samples([], then: .offline)])
        let store = try Self.store(Self.serverChosen(), meter)

        await store.send(.tokenResponse(.success(token))) {
            $0.token = token
        }
        await store.receive(\.transferResponse) {
            $0.phase = .failed(.offline)
        }

        #expect(meter.starts.value.count == 1)
    }

    @Test(arguments: [
        (SpeedTestError.connectionLost, SpeedTest.Interruption.connectionLost),
        (.networkChanged, .networkChanged)
    ])
    func anInterruptedDownloadKeepsAPartialResult(
        error: SpeedTestError,
        reason: SpeedTest.Interruption
    ) async throws {
        let meter = RunFakes.Meter([.samples([download1], then: error)])
        let store = try Self.store(Self.serverChosen(), meter)

        await store.send(.tokenResponse(.success(token))) {
            $0.token = token
        }
        await store.receive(\.sampled) {
            $0.downloadSamples = [download1]
            $0.phase = .downloading
        }
        await store.receive(\.transferResponse) {
            $0.download = TransferResult(lastSample: download1, wasPartial: true)
            $0.phase = .interrupted(reason)
        }
    }

    @Test func anInterruptedUploadKeepsTheDownload() async throws {
        let meter = RunFakes.Meter([.samples([download1]), .samples([upload1], then: .connectionLost)])
        let store = try Self.store(Self.serverChosen(), meter)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tokenResponse(.success(token)))
        await store.receive(\.transferResponse)
        await store.receive(\.sampled)
        await store.receive(\.transferResponse)

        #expect(store.state.download == TransferResult(lastSample: download1, wasPartial: false))
        #expect(store.state.upload == TransferResult(lastSample: upload1, wasPartial: true))
        #expect(store.state.phase == .interrupted(.connectionLost))
    }

    @Test func anUploadThatCannotStartStillFinishes() async throws {
        let meter = RunFakes.Meter([.samples([download1]), .samples([], then: .transferFailed)])
        let store = try Self.store(Self.serverChosen(), meter)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tokenResponse(.success(token)))
        await store.receive(\.transferResponse)
        await store.receive(\.transferResponse)

        #expect(store.state.isUploadUnavailable)
        #expect(store.state.upload == nil)
        #expect(store.state.phase == .finished)
        #expect(try await Self.history(store).map(\.uploadMbps) == [nil])
    }

    @Test func stopDuringTheDownloadKeepsAPartialAverage() async throws {
        let meter = RunFakes.Meter([.samplesThenWait([download1])])
        let store = try Self.store(Self.serverChosen(), meter)

        await store.send(.tokenResponse(.success(token))) {
            $0.token = token
        }
        await store.receive(\.sampled) {
            $0.downloadSamples = [download1]
            $0.phase = .downloading
        }
        await store.send(\.view.startStopTapped) {
            $0.download = TransferResult(lastSample: download1, wasPartial: true)
            $0.phase = .interrupted(.stopped)
        }

        // Only finished runs are kept.
        #expect(try await Self.history(store).isEmpty)
    }

    @Test func stopDuringTheUploadKeepsTheDownloadAndAPartialUpload() async throws {
        let meter = RunFakes.Meter([.samples([download1]), .samplesThenWait([upload1])])
        let store = try Self.store(Self.serverChosen(), meter)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tokenResponse(.success(token)))
        await store.receive(\.transferResponse)
        await store.receive(\.sampled)
        await store.send(\.view.startStopTapped)

        #expect(store.state.download == TransferResult(lastSample: download1, wasPartial: false))
        #expect(store.state.upload == TransferResult(lastSample: upload1, wasPartial: true))
        #expect(store.state.phase == .interrupted(.stopped))
    }

    /// Stop, then Start straight away, starts a clean new run.
    @Test func stopThenStartRunsAgainFromAClearScreen() async throws {
        let meter = RunFakes.Meter([.samplesThenWait([download1])])
        let store = try Self.store(Self.serverChosen(), meter) {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = RunFakes.Directory(servers: .success([])).client
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.tokenResponse(.success(token)))
        await store.receive(\.sampled)
        await store.send(\.view.startStopTapped)

        store.exhaustivity = .on
        await store.send(\.view.startStopTapped) {
            $0 = SpeedTest.State()
            $0.phase = .locating
        }
        await store.receive(\.located) {
            $0.location = .located(Fixtures.prague)
            $0.phase = .fetchingServers
        }
        await store.receive(\.clientIPResponse.success) {
            $0.clientIP = Fixtures.clientIP
        }
        await store.receive(\.serversResponse.success) {
            $0.phase = .failed(.noServers)
        }
    }

    // MARK: - Support

    /// Elektro Solution Prague on ports 81 and 88 (one host), then jablonka.cz; the first one is chosen. The
    /// failover target is jablonka.cz: the other port is on the host that just failed.
    private static func serverChosen(measuresUpload: Bool = true) throws -> SpeedTest.State {
        let candidates = Fixtures.candidates
        let order = try [
            #require(candidates.first { $0.server.provider == "Elektro Solution" && $0.server.port == 81 }),
            #require(candidates.first { $0.server.provider == "Elektro Solution" && $0.server.port == 88 }),
            #require(candidates.first { $0.server.provider == "jablonka.cz" })
        ]
        var state = SpeedTest.State()
        state.location = .located(Fixtures.prague)
        state.candidates = IdentifiedArray(uniqueElements: order)
        state.order = order
        state.selection = SpeedTest.Selection(server: order[0].server, ping: nil, reason: .lowestPing)
        state.phase = .connecting(.download)
        state.$measuresUpload.withLock { $0 = measuresUpload }
        return state
    }

    static let now = Date(timeIntervalSince1970: 1_790_900_000)

    /// A fresh, migrated database per store, and a fixed clock for the entries' dates.
    private static func store(
        _ state: SpeedTest.State,
        _ meter: RunFakes.Meter,
        dependencies: (inout DependencyValues) -> Void = { _ in }
    ) throws -> TestStoreOf<SpeedTest> {
        let database = try historyDatabase()
        return TestStore(initialState: state) {
            SpeedTest()
        } withDependencies: {
            $0.transferMeter = meter.client
            $0.defaultDatabase = database
            $0.date = .constant(now)
            dependencies(&$0)
        }
    }

    /// Every saved entry, once the save effect has finished: it writes on the database's own queue, so the run's
    /// last action can be received before the row is there.
    private static func history(_ store: TestStoreOf<SpeedTest>) async throws -> [HistoryEntry] {
        await store.finish()
        return try await store.dependencies.defaultDatabase.read { db in
            try HistoryEntry.all.fetchAll(db)
        }
    }
}
