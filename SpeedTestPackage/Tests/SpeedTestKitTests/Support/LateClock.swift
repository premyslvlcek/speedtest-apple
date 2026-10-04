//
//  LateClock.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 04.10.2026.
//

import Clocks

/// An `ImmediateClock` that wakes every sleeper a little after its deadline, as a real clock does. The test clocks
/// wake exactly on time, which hides a rule that only holds when wake-ups are on time.
struct LateClock: Clock {
    private let base = ImmediateClock()
    private let lateness: Duration = .milliseconds(1)

    var now: ImmediateClock<Duration>.Instant {
        base.now
    }

    var minimumResolution: Duration {
        base.minimumResolution
    }

    func sleep(until deadline: ImmediateClock<Duration>.Instant, tolerance: Duration?) async throws {
        try await base.sleep(until: deadline.advanced(by: lateness), tolerance: tolerance)
    }
}
