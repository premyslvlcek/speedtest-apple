//
//  Stopwatch.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// Elapsed time since creation, on any clock measured in `Duration`.
struct Stopwatch: Sendable {
    private let read: @Sendable () -> Duration

    init(clock: any Clock<Duration>) {
        read = Self.reader(for: clock)
    }

    func elapsed() -> Duration {
        read()
    }

    /// Opening the existential here gives us a concrete `C.Instant` to subtract.
    private static func reader<C: Clock>(for clock: C) -> @Sendable () -> Duration where C.Duration == Duration {
        let origin = clock.now
        return { origin.duration(to: clock.now) }
    }
}
