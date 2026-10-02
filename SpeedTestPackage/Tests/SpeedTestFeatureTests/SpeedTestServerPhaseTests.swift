//
//  SpeedTestServerPhaseTests.swift
//  SpeedTestFeatureTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import Foundation
import ICMP
import SpeedTestKit
import SwiftUI
import Testing
import TestSupport

@testable import HistoryFeature
@testable import SpeedTestFeature

/// From Start to the chosen server: locate, fetch, ping each host once, choose, get the token. The selection rules
/// themselves are `ServerSelector`'s (ServerSelectorTests); these tests check that the reducer drives the steps.
@MainActor
@Suite(.mainSerialExecutor) struct SpeedTestServerPhaseTests {
    @Test func startLocatesFetchesPingsAndChoosesTheFastest() async {
        let directory = RunFakes.Directory()
        let pings = RunFakes.Pings()
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = directory.client
            $0.pingService = pings.client
            // The run goes on to measure; these tests stop it there.
            $0.transferMeter = RunFakes.Meter([.samplesThenWait([])]).client
        }
        let candidates = Fixtures.candidates
        var pinged = IdentifiedArray(uniqueElements: candidates)

        await store.send(\.view.startStopTapped) {
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
            $0.candidates = IdentifiedArray(uniqueElements: candidates)
            $0.phase = .pinging
        }

        // One ping per distinct host, applied to every entry of that host: the two Elektro Solution Prague ports
        // share one.
        let hosts = candidates.map(\.server.host).reduce(into: [String]()) { hosts, host in
            if !hosts.contains(host) {
                hosts.append(host)
            }
        }
        for (index, host) in hosts.enumerated() {
            let result = Fixtures.pingResult(forHost: host) ?? .noReply(sent: 5)
            for candidate in candidates where candidate.server.host == host {
                pinged[id: candidate.id]?.ping = .finished(result)
            }
            let isLast = index == hosts.count - 1
            await store.receive(\.pinged) { [pinged] in
                $0.candidates = pinged
                if isLast {
                    $0.order = Self.order(pinged.elements)
                    let fastest = $0.order[0]
                    $0.selection = SpeedTest.Selection(
                        server: fastest.server,
                        ping: fastest.pingResult,
                        reason: .lowestPing
                    )
                    $0.phase = .connecting(.download)
                }
            }
        }
        await store.receive(\.tokenResponse.success) {
            $0.token = RunFakes.token
        }
        await store.send(\.view.startStopTapped) {
            $0.phase = .interrupted(.stopped)
        }

        #expect(store.state.selection?.server.provider == "Elektro Solution")
        #expect(store.state.selection?.server.port == 81)
        #expect(pings.hosts.value == hosts)
        #expect(directory.fetchedNear.value == [Fixtures.prague])
        #expect(directory.tokenCalls.value == 1)
    }

    @Test func withoutALocationItFetchesByIP() async throws {
        let server = try #require(Fixtures.servers.first { $0.provider == "Ubiquiti" })
        let directory = RunFakes.Directory(servers: .success([server]))
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator(.notAuthorized)
            $0.serverDirectory = directory.client
            $0.pingService = RunFakes.Pings().client
            // The run goes on to measure; these tests stop it there.
            $0.transferMeter = RunFakes.Meter([.samplesThenWait([])]).client
        }

        await store.send(\.view.startStopTapped) {
            $0.phase = .locating
        }
        await store.receive(\.located) {
            $0.location = .notAuthorized
            $0.phase = .fetchingServers
        }
        await store.receive(\.clientIPResponse.success) {
            $0.clientIP = Fixtures.clientIP
        }
        await store.receive(\.serversResponse.success) {
            $0.candidates = [Candidate(server: server, distance: nil)]
            $0.phase = .pinging
        }
        let result = try #require(Fixtures.pingResults[server.id])
        let replied = Candidate(server: server, distance: nil, ping: .finished(result))
        await store.receive(\.pinged) {
            $0.candidates = [replied]
            $0.order = [replied]
            $0.selection = SpeedTest.Selection(server: server, ping: replied.pingResult, reason: .lowestPing)
            $0.phase = .connecting(.download)
        }
        await store.receive(\.tokenResponse.success) {
            $0.token = RunFakes.token
        }
        await store.send(\.view.startStopTapped) {
            $0.phase = .interrupted(.stopped)
        }

        #expect(directory.fetchedNear.value == [nil])
    }

    @Test func whenNoHostRepliesTheChoiceIsMarkedICMPBlocked() async throws {
        let server = try #require(Fixtures.servers.first { $0.city == "Zbožíčko" })
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = RunFakes.Directory(servers: .success([server])).client
            $0.pingService = RunFakes.Pings().client
            // The run goes on to measure; these tests stop it there.
            $0.transferMeter = RunFakes.Meter([.samplesThenWait([])]).client
        }
        store.exhaustivity = .off

        await store.send(\.view.startStopTapped)
        await store.receive(\.tokenResponse.success)

        #expect(store.state.selection?.reason == .icmpBlocked)
        #expect(store.state.selection?.ping == .noReply(sent: 5))
        await store.send(\.view.startStopTapped)
    }

    @Test func anEmptyDirectoryFails() async {
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = RunFakes.Directory(servers: .success([])).client
        }

        await store.send(\.view.startStopTapped) {
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

    /// The address is extra information: a lookup that fails changes nothing and the run carries on.
    @Test func aFailedIPLookupLeavesTheRunAlone() async {
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = RunFakes.Directory(
                servers: .success([]),
                clientIP: .failure(SpeedTestError.directoryUnavailable)
            ).client
        }

        await store.send(\.view.startStopTapped) {
            $0.phase = .locating
        }
        await store.receive(\.located) {
            $0.location = .located(Fixtures.prague)
            $0.phase = .fetchingServers
        }
        await store.receive(\.clientIPResponse.failure)
        await store.receive(\.serversResponse.success) {
            $0.phase = .failed(.noServers)
        }
    }

    @Test func historyOpensTheHistorySheet() async throws {
        let database = try historyDatabase()
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(\.view.historyTapped) {
            $0.history = History.State()
        }
    }

    @Test func aBusyDirectoryFailsWithoutARetry() async {
        let directory = RunFakes.Directory(servers: .failure(HTTPStatusError(statusCode: 429)))
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = directory.client
        }

        await store.send(\.view.startStopTapped) {
            $0.phase = .locating
        }
        await store.receive(\.located) {
            $0.location = .located(Fixtures.prague)
            $0.phase = .fetchingServers
        }
        await store.receive(\.clientIPResponse.success) {
            $0.clientIP = Fixtures.clientIP
        }
        await store.receive(\.serversResponse.failure) {
            $0.phase = .failed(.rateLimited)
        }

        #expect(directory.fetchedNear.value.count == 1)
    }

    @Test func aTokenRequestThatFailsEndsTheRunWithoutARetry() async throws {
        let server = try #require(Fixtures.servers.first { $0.provider == "Ubiquiti" })
        let directory = RunFakes.Directory(
            servers: .success([server]),
            token: .failure(URLError(.notConnectedToInternet))
        )
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = directory.client
            $0.pingService = RunFakes.Pings().client
        }
        store.exhaustivity = .off

        await store.send(\.view.startStopTapped)
        await store.receive(\.tokenResponse.failure)

        #expect(store.state.phase == .failed(.offline))
        #expect(directory.tokenCalls.value == 1)
    }

    /// Stop before any sample exists leaves no partial numbers.
    @Test func stopWhilePingingHasNoPartialResult() async {
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = RunFakes.Directory().client
            $0.pingService = RunFakes.pingUntilCancelled
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(\.view.startStopTapped)
        await store.receive(\.serversResponse.success)
        await store.send(\.view.startStopTapped)

        #expect(store.state.phase == .interrupted(.stopped))
        #expect(store.state.download == nil)
        #expect(store.state.upload == nil)
    }

    #if os(iOS)
        @Test func goingToTheBackgroundInterruptsTheRun() async {
            let store = TestStore(initialState: SpeedTest.State()) {
                SpeedTest()
            } withDependencies: {
                $0.locator = RunFakes.locator()
                $0.serverDirectory = RunFakes.Directory().client
                $0.pingService = RunFakes.pingUntilCancelled
            }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(\.view.startStopTapped)
            await store.receive(\.serversResponse.success)
            await store.send(\.view.scenePhaseChanged, .background)

            #expect(store.state.phase == .interrupted(.background))
        }
    #endif

    /// Control Center and the location prompt make the scene inactive; neither may stop a run. On the Mac even
    /// the background doesn't.
    @Test func becomingInactiveDoesNotInterrupt() async {
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = RunFakes.Directory().client
            $0.pingService = RunFakes.pingUntilCancelled
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(\.view.startStopTapped)
        await store.receive(\.serversResponse.success)
        await store.send(\.view.scenePhaseChanged, .inactive)
        #if os(macOS)
            await store.send(\.view.scenePhaseChanged, .background)
        #endif

        #expect(store.state.phase == .pinging)
        await store.send(\.view.startStopTapped)
    }

    @Test func retryAfterAFailureRunsAgain() async {
        let directory = RunFakes.Directory(servers: .failure(HTTPStatusError(statusCode: 500)))
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.locator = RunFakes.locator()
            $0.serverDirectory = directory.client
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(\.view.startStopTapped)
        await store.receive(\.serversResponse.failure)

        await store.send(\.view.retryTapped) {
            $0.phase = .locating
            $0.location = nil
        }
        await store.receive(\.serversResponse.failure)

        #expect(store.state.phase == .failed(.directoryUnavailable))
        #expect(directory.fetchedNear.value.count == 2)
    }

    @Test func theUploadSwitchChangesTheRememberedSetting() async {
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        }

        await store.send(\.view.uploadToggled, true) {
            $0.$measuresUpload.withLock { $0 = true }
        }
    }

    @Test func theUploadSwitchIsIgnoredDuringARun() async {
        var state = SpeedTest.State()
        state.phase = .pinging
        let store = TestStore(initialState: state) {
            SpeedTest()
        }

        await store.send(\.view.uploadToggled, true)
    }

    @Test func openSettingsOpensTheSettingsURL() async {
        let opened = LockIsolated<URL?>(nil)
        let store = TestStore(initialState: SpeedTest.State()) {
            SpeedTest()
        } withDependencies: {
            $0.openURL = OpenURLEffect { url in
                opened.setValue(url)
                return true
            }
        }

        await store.send(\.view.openSettingsTapped)

        #expect(opened.value == SpeedTest.settingsURL)
    }

    /// The fallback order the reducer is expected to keep: the selector's, with the standard reply threshold.
    private static func order(_ candidates: [Candidate]) -> [Candidate] {
        ServerSelector.order(candidates, minimumReplies: SpeedTestConfiguration.standard.minimumReplies)
    }
}
