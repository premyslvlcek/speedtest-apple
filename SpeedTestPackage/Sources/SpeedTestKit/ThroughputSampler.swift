//
//  ThroughputSampler.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// Turns `(elapsed since the first byte, total bytes)` readings into samples.
///
/// Pure: the transfer meter owns the clock and the 250 ms tick, reads the byte counter and calls `add`.
/// Readings must arrive in increasing `elapsed` order.
struct ThroughputSampler: Sendable {
    private struct Reading: Sendable {
        var elapsed: Duration
        var totalBytes: Int64
    }

    private let window: Duration
    /// Where the average starts: t0, or the end of a warm-up whose bytes are left out (upload).
    private let averageFrom: Duration
    /// Every reading so far, starting with the origin (t0, no bytes). A 15 s transfer sampled every 250 ms
    /// adds 60, which is too few to be worth pruning.
    private var readings = [Reading(elapsed: .zero, totalBytes: 0)]

    init(window: Duration, averageFrom: Duration = .zero) {
        self.window = window
        self.averageFrom = averageFrom
    }

    mutating func add(elapsed: Duration, totalBytes: Int64) -> ThroughputSample {
        // The latest reading at or before the window's start; in the first window there is none, so the origin.
        let base = readings.last { $0.elapsed <= elapsed - window } ?? readings[0]
        // Until the warm-up has passed there's nothing after it to average: until then, from t0.
        let averageBase = elapsed > averageFrom
            ? readings.last { $0.elapsed <= averageFrom } ?? readings[0]
            : readings[0]
        readings.append(Reading(elapsed: elapsed, totalBytes: totalBytes))

        return ThroughputSample(
            elapsed: elapsed,
            totalBytes: totalBytes,
            // A refused upload connection takes its bytes back out, so the total can go down: zero, never negative.
            currentMbps: max(
                0,
                Self.megabitsPerSecond(bytes: totalBytes - base.totalBytes, over: elapsed - base.elapsed)
            ),
            averageMbps: max(
                0,
                Self.megabitsPerSecond(bytes: totalBytes - averageBase.totalBytes, over: elapsed - averageBase.elapsed)
            )
        )
    }

    /// Decimal megabits (10⁶ bits) per second. Zero for an empty span, never NaN.
    static func megabitsPerSecond(bytes: Int64, over duration: Duration) -> Double {
        let seconds = duration.inSeconds
        guard seconds > 0 else {
            return 0
        }

        let megabits = Double(bytes) * bitsPerByte / bitsPerMegabit
        return megabits / seconds
    }

    private static let bitsPerByte = 8.0
    private static let bitsPerMegabit = 1_000_000.0
}
