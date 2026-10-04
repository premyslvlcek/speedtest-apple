//
//  ErrorMapping.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

public extension SpeedTestError {
    /// The mapping for a run. Every error that ends a run goes through it, in the transfer meter and in the
    /// reducer, so a run ends only with a `SpeedTestError`. `nil` means the run was cancelled (Stop): end quietly.
    static func mapping(_ error: any Error) -> SpeedTestError? {
        if let error = error as? SpeedTestError {
            return error
        }
        if isCancellation(error) {
            return nil
        }
        if let error = error as? URLError, error.isOffline {
            return .offline
        }
        return .transferFailed
    }

    /// The mapping for the directory and token endpoints: the device is offline, the service is busy, or it's
    /// unavailable for any other reason. Nothing here is retried automatically. `nil` means the request was
    /// cancelled (Stop), exactly as in `mapping`.
    static func directoryMapping(_ error: any Error) -> SpeedTestError? {
        if let error = error as? SpeedTestError {
            return error
        }
        if isCancellation(error) {
            return nil
        }
        // The directory is a single request, so a connection dropped mid-request most likely means the network
        // went away. (During a run, `mapping` treats it as a transfer failure: there, failover applies.)
        if let error = error as? URLError, error.isOffline || error.code == .networkConnectionLost {
            return .offline
        }
        if let error = error as? HTTPStatusError, error.statusCode == HTTPStatusError.tooManyRequests {
            return .rateLimited
        }
        return .directoryUnavailable
    }
}

extension SpeedTestError {
    /// Stop cancels the task. `URLSession` reports that as `URLError.cancelled`, everything else as
    /// `CancellationError`.
    static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let error = error as? URLError, error.code == .cancelled {
            return true
        }
        return false
    }
}

extension URLError {
    /// The codes that mean this device has no usable network at all.
    var isOffline: Bool {
        switch code {
        case .dataNotAllowed, .internationalRoamingOff, .notConnectedToInternet:
            true

        default:
            false
        }
    }
}
