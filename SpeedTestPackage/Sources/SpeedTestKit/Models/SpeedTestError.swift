//
//  SpeedTestError.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The only errors a run ends with: the transfer meter and the reducer map everything else to one of these.
/// Cancellation isn't one of them: Stop ends a run quietly.
public enum SpeedTestError: Error, Sendable, Equatable {
    case offline
    case directoryUnavailable
    /// The directory answered 429. Never retried automatically.
    case rateLimited
    case noServers
    /// The first choice and the failover both failed before their first byte.
    case transferFailed
    /// The primary network interface changed after the first byte.
    case networkChanged
    /// Every connection failed after the first byte.
    case connectionLost

    /// Interruptions end a run that already has a partial result.
    public var isInterruption: Bool {
        switch self {
        case .connectionLost, .networkChanged:
            true

        case .directoryUnavailable, .noServers, .offline, .rateLimited, .transferFailed:
            false
        }
    }
}
