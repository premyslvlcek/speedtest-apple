//
//  Stopwatch.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// Time elapsed since creation, on any `Clock<Duration>`.
///
/// Two instants of an `any Clock<Duration>` can't be subtracted, because their concrete type is hidden.
/// The generic helper opens the existential once (SE-0352), so `elapsed()` works on the real clock in the
/// app and on a test clock in tests. `package`: the transfer meter in SpeedTestKit uses it too.
package struct Stopwatch: Sendable {
    private let read: @Sendable () -> Duration

    package init(clock: any Clock<Duration>) {
        read = Self.reader(for: clock)
    }

    package func elapsed() -> Duration {
        read()
    }

    private static func reader<C: Clock>(for clock: C) -> @Sendable () -> Duration where C.Duration == Duration {
        let origin = clock.now
        return { origin.duration(to: clock.now) }
    }
}
