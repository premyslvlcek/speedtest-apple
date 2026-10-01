//
//  LocationOutcome.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// What locating produced. Anything but `.located` puts the run in approximate mode; it never fails.
public enum LocationOutcome: Sendable, Equatable {
    case located(Coordinate)
    /// Denied or restricted.
    case notAuthorized
    /// Timed out, an error, or no fix (e.g. a Mac desktop without Wi-Fi).
    case unavailable

    public var coordinate: Coordinate? {
        switch self {
        case let .located(coordinate):
            coordinate

        case .notAuthorized, .unavailable:
            nil
        }
    }
}
