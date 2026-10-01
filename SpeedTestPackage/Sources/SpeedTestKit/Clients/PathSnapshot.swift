//
//  PathSnapshot.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The two facts about a network path that decide whether a transfer was interrupted.
struct PathSnapshot: Sendable, Equatable {
    enum Interface: Sendable, Equatable {
        case wifi
        case cellular
        case wired
        case other
    }

    var isSatisfied: Bool
    var primaryInterface: Interface?

    /// A run is interrupted when the path stops being usable or its primary interface changes, e.g. Wi-Fi to
    /// cellular. A secondary interface appearing, or the expensive/constrained flags flipping, is not modelled
    /// here, so it never interrupts a run.
    static func isInterruption(baseline: PathSnapshot, current: PathSnapshot) -> Bool {
        guard current.isSatisfied else {
            return true
        }

        return current.primaryInterface != baseline.primaryInterface
    }
}
