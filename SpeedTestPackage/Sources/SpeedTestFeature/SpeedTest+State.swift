//
//  SpeedTest+State.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import SpeedTestKit

extension SpeedTest.State {
    /// From Start until the run finishes, fails or is interrupted.
    public var isRunning: Bool {
        switch phase {
        case .connecting, .downloading, .fetchingServers, .locating, .pinging, .uploading:
            true

        case .failed, .finished, .idle, .interrupted:
            false
        }
    }

    /// Clears the previous run.
    mutating func reset() {
        self = Self()
    }

    mutating func select(_ candidate: Candidate, reason: SelectionReason) {
        selection = SpeedTest.Selection(server: candidate.server, ping: candidate.pingResult, reason: reason)
    }

    /// Ends the run early. The partial result is the last sample of whichever transfer was running; nothing is
    /// invented when no sample exists yet.
    mutating func interrupt(_ reason: SpeedTest.Interruption) {
        if download == nil, let last = downloadSamples.last {
            download = TransferResult(lastSample: last, wasPartial: true)
        } else if download != nil, upload == nil, let last = uploadSamples.last {
            upload = TransferResult(lastSample: last, wasPartial: true)
        }

        phase = .interrupted(reason)
    }
}
