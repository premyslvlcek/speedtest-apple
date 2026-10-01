//
//  SpeedTestEvent.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ICMP

/// Everything a run reports, in order. The stream then finishes, or fails with a `SpeedTestError`.
public enum SpeedTestEvent: Sendable, Equatable {
    case locating
    case located(LocationOutcome)
    /// Their pings are still `.pending`.
    case candidatesFound([Candidate])
    case pinged(Server.ID, PingResult)
    case serverSelected(Server, PingResult?, reason: SelectionReason)
    /// Connecting. The first `downloadSample` means the first byte arrived.
    case downloadStarted
    case downloadSample(ThroughputSample)
    case downloadFinished(TransferResult)
    case uploadStarted
    case uploadSample(ThroughputSample)
    case uploadFinished(TransferResult)
    /// The upload couldn't start after a successful download. The run still completes.
    case uploadUnavailable
}
