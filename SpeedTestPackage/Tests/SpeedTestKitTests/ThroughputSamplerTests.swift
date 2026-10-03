//
//  ThroughputSamplerTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Testing

@testable import SpeedTestKit

@Suite struct ThroughputSamplerTests {
    @Test func theFirstSampleMeasuresFromTheFirstByte() {
        var sampler = ThroughputSampler(window: .seconds(1))

        let sample = sampler.add(elapsed: .milliseconds(250), totalBytes: 1_250_000)

        // 10 Mb over the 0.25 s since t0, not spread over a full second.
        #expect(sample.currentMbps.isClose(to: 40))
        #expect(sample.averageMbps.isClose(to: 40))
    }

    @Test func untilOneSecondTheWindowStartsAtTheFirstByte() {
        var sampler = ThroughputSampler(window: .seconds(1))
        _ = sampler.add(elapsed: .milliseconds(250), totalBytes: 1_000_000)
        _ = sampler.add(elapsed: .milliseconds(500), totalBytes: 2_000_000)
        _ = sampler.add(elapsed: .milliseconds(750), totalBytes: 3_000_000)

        let sample = sampler.add(elapsed: .seconds(1), totalBytes: 4_000_000)

        // 32 Mb over exactly 1 s, measured from t0.
        #expect(sample.currentMbps.isClose(to: 32))
        #expect(sample.averageMbps.isClose(to: 32))
    }

    @Test func afterOneSecondTheWindowSlides() {
        var sampler = ThroughputSampler(window: .seconds(1))
        _ = sampler.add(elapsed: .milliseconds(250), totalBytes: 1_000_000)
        _ = sampler.add(elapsed: .milliseconds(500), totalBytes: 2_000_000)
        _ = sampler.add(elapsed: .milliseconds(750), totalBytes: 3_000_000)
        _ = sampler.add(elapsed: .seconds(1), totalBytes: 4_000_000)

        let sample = sampler.add(elapsed: .milliseconds(1250), totalBytes: 6_000_000)

        // The window now starts at the 0.25 s reading: 5 MB in exactly 1.0 s.
        #expect(sample.currentMbps.isClose(to: 40))
        // 48 Mb over 1.25 s.
        #expect(sample.averageMbps.isClose(to: 38.4))
    }

    @Test func anUnalignedReadingUsesTheLatestReadingAtOrBeforeTheWindowStart() {
        var sampler = ThroughputSampler(window: .seconds(1))
        _ = sampler.add(elapsed: .milliseconds(500), totalBytes: 2_000_000)

        let sample = sampler.add(elapsed: .milliseconds(1100), totalBytes: 5_500_000)

        // The window would start at 0.1 s. The latest reading at or before that is t0, so the span is 1.1 s.
        #expect(sample.currentMbps.isClose(to: 40))
        #expect(sample.averageMbps.isClose(to: 40))
    }

    @Test func aStalledLineReadsZeroNowWhileTheAverageStays() {
        var sampler = ThroughputSampler(window: .seconds(1))
        let readings: [(Int, Int64)] = [
            (250, 1_000_000), (500, 2_000_000), (750, 3_000_000), (1000, 4_000_000),
            (1250, 4_000_000), (1500, 4_000_000), (1750, 4_000_000)
        ]
        for (milliseconds, bytes) in readings {
            _ = sampler.add(elapsed: .milliseconds(milliseconds), totalBytes: bytes)
        }

        let sample = sampler.add(elapsed: .seconds(2), totalBytes: 4_000_000)

        #expect(sample.currentMbps == 0)
        #expect(sample.averageMbps.isClose(to: 16))
    }

    /// A refused upload connection takes its bytes back out of the total, so the count can go down.
    @Test func aCountThatGoesDownReadsZeroNowNotANegativeSpeed() {
        var sampler = ThroughputSampler(window: .seconds(1))
        _ = sampler.add(elapsed: .milliseconds(250), totalBytes: 1_000_000)
        _ = sampler.add(elapsed: .milliseconds(500), totalBytes: 2_000_000)
        _ = sampler.add(elapsed: .milliseconds(750), totalBytes: 3_000_000)
        _ = sampler.add(elapsed: .seconds(1), totalBytes: 4_000_000)
        // The window now starts at the 0.25 s reading (1 MB), above the new total.
        let sample = sampler.add(elapsed: .milliseconds(1250), totalBytes: 500_000)

        #expect(sample.currentMbps == 0)
        #expect(sample.averageMbps.isClose(to: 3.2))
        // Below what was counted at t0: the average is zero too.
        #expect(sampler.add(elapsed: .milliseconds(1500), totalBytes: -1000).averageMbps == 0)
    }

    /// Upload bytes count when handed to the network stack, which takes a chunk per connection at once: the first
    /// second is left out of the upload's average, so that head start cancels out.
    @Test func theAverageCanStartAfterAWarmUp() {
        var sampler = ThroughputSampler(window: .seconds(1), averageFrom: .seconds(1))
        // 4 MB counted at once, then 1 MB every 250 ms.
        _ = sampler.add(elapsed: .milliseconds(250), totalBytes: 4_000_000)
        _ = sampler.add(elapsed: .milliseconds(500), totalBytes: 5_000_000)
        _ = sampler.add(elapsed: .milliseconds(750), totalBytes: 6_000_000)
        let warmingUp = sampler.add(elapsed: .seconds(1), totalBytes: 7_000_000)
        _ = sampler.add(elapsed: .milliseconds(1250), totalBytes: 8_000_000)
        _ = sampler.add(elapsed: .milliseconds(1500), totalBytes: 9_000_000)
        _ = sampler.add(elapsed: .milliseconds(1750), totalBytes: 10_000_000)

        let sample = sampler.add(elapsed: .seconds(2), totalBytes: 11_000_000)

        // Until the warm-up ends, the average runs from t0: 56 Mb over 1 s.
        #expect(warmingUp.averageMbps.isClose(to: 56))
        // After it, from the warm-up's end: 4 MB over 1 s, not 11 MB over 2 s (44 Mbps).
        #expect(sample.averageMbps.isClose(to: 32))
    }
}

private extension Double {
    /// Rates are computed in floating point, so they're compared within a rounding error, not for equality.
    static let roundingTolerance = 1e-9

    func isClose(to other: Double) -> Bool {
        abs(self - other) < Self.roundingTolerance
    }
}
