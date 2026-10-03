//
//  StateFixtures.swift
//  SpeedTestFeatureTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import Foundation
import ICMP
import SpeedTestKit

@testable import SpeedTestFeature

/// One `State` per screen state, built from the shared fixtures so the numbers look real.
extension SpeedTest.State {
    static let downloadSeries = Fixtures.samples(
        peakMbps: 486, duration: .seconds(15), interval: .milliseconds(250)
    )
    static let uploadSeries = Fixtures.samples(
        peakMbps: 92, duration: .seconds(10), interval: .milliseconds(250)
    )

    /// Every candidate with its ping result, nearest first.
    static var pingedCandidates: IdentifiedArrayOf<Candidate> {
        var candidates = IdentifiedArray(uniqueElements: Fixtures.candidates)
        for id in candidates.ids {
            if let result = Fixtures.pingResults[id] {
                candidates[id: id]?.ping = .finished(result)
            }
        }
        return candidates
    }

    static var winnerSelection: SpeedTest.Selection? {
        guard let winner = ServerSelector.order(
            Array(pingedCandidates),
            minimumReplies: SpeedTestConfiguration.standard.minimumReplies
        ).first,
            case let .finished(result) = winner.ping
        else {
            return nil
        }

        return SpeedTest.Selection(server: winner.server, ping: result, reason: .lowestPing)
    }

    /// Idle, first launch.
    static var idleFixture: Self {
        Self()
    }

    /// Pinging: two servers have answered, three are pending.
    static var pingingFixture: Self {
        var state = Self()
        state.phase = .pinging
        state.location = .located(Fixtures.prague)
        state.candidates = IdentifiedArray(uniqueElements: Fixtures.candidates)
        for id in state.candidates.ids.prefix(2) {
            if let result = Fixtures.pingResults[id] {
                state.candidates[id: id]?.ping = .finished(result)
            }
        }
        return state
    }

    /// Downloading, 7.5 s in.
    static var downloadingFixture: Self {
        var state = Self()
        state.phase = .downloading
        state.location = .located(Fixtures.prague)
        state.candidates = pingedCandidates
        state.selection = winnerSelection
        state.downloadSamples = Array(downloadSeries.prefix(30))
        return state
    }

    /// Finished: download and upload averages.
    static var finishedFixture: Self {
        var state = downloadingFixture
        state.downloadSamples = downloadSeries
        state.download = downloadSeries.last.map { TransferResult(lastSample: $0, wasPartial: false) }
        state.uploadSamples = uploadSeries
        state.upload = uploadSeries.last.map { TransferResult(lastSample: $0, wasPartial: false) }
        state.phase = .finished
        return state
    }

    /// Stopped by the user at 7.5 s.
    static var stoppedFixture: Self {
        var state = downloadingFixture
        state.interrupt(.stopped)
        return state
    }

    /// Degraded: location off (servers by IP, no distances), ICMP blocked, still downloading.
    static var degradedFixture: Self {
        var state = Self()
        state.phase = .downloading
        state.location = .notAuthorized
        let approximate = Fixtures.candidates.map {
            Candidate(server: $0.server, distance: nil, ping: .finished(.noReply(sent: 5)))
        }
        state.candidates = IdentifiedArray(uniqueElements: approximate)
        if let first = approximate.first {
            state.selection = SpeedTest.Selection(server: first.server, ping: nil, reason: .icmpBlocked)
        }
        state.downloadSamples = Array(downloadSeries.prefix(12))
        return state
    }

    /// Failed: offline.
    static var failedFixture: Self {
        var state = Self()
        state.phase = .failed(.offline)
        return state
    }
}
