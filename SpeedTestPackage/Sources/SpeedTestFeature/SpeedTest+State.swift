//
//  SpeedTest+State.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import Foundation
import HistoryFeature
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

    /// The first sample of a transfer is its first byte: the phase moves from connecting to measuring.
    mutating func record(_ sample: ThroughputSample, _ direction: TransferDirection) {
        switch direction {
        case .download:
            downloadSamples.append(sample)
            phase = .downloading

        case .upload:
            uploadSamples.append(sample)
            phase = .uploading
        }
    }

    mutating func finishUpload() {
        if let last = uploadSamples.last {
            upload = TransferResult(lastSample: last, wasPartial: false)
        }
        phase = .finished
    }

    /// An upload that can't start doesn't spoil the run: it finishes with the download alone. An interruption keeps
    /// the partial upload.
    mutating func uploadFailed(_ error: any Error) {
        guard let error = SpeedTestError.mapping(error) else {
            return
        }
        guard !error.isInterruption else {
            end(with: error)
            return
        }

        isUploadUnavailable = true
        phase = .finished
    }

    /// An interruption keeps a partial result; anything else is a failure.
    mutating func end(with error: SpeedTestError) {
        switch error {
        case .connectionLost:
            interrupt(.connectionLost)

        case .networkChanged:
            interrupt(.networkChanged)

        case .directoryUnavailable, .noServers, .offline, .rateLimited, .transferFailed:
            phase = .failed(error)
        }
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

extension SpeedTest.State {
    /// What the history keeps of this run: the server, the ping, both averages and the address.
    func historyEntry(date: Date) -> HistoryEntry.Draft? {
        guard let server = selection?.server, let download else {
            return nil
        }
        return HistoryEntry.Draft(
            recordedAt: date,
            serverProvider: server.provider,
            serverCity: server.city,
            pingMilliseconds: selection?.ping?.median?.inMilliseconds,
            downloadMbps: download.averageMbps,
            uploadMbps: upload?.averageMbps,
            ipAddress: clientIP?.address,
            ipProvider: clientIP?.provider
        )
    }
}
