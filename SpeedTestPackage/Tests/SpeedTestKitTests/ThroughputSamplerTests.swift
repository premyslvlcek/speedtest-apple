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

    @Test func aReadingAtT0IsZeroNotNaN() {
        var sampler = ThroughputSampler(window: .seconds(1))

        let sample = sampler.add(elapsed: .zero, totalBytes: 0)

        #expect(sample.currentMbps == 0)
        #expect(sample.averageMbps == 0)
    }

    @Test func theWindowLengthIsConfigurable() {
        var sampler = ThroughputSampler(window: .milliseconds(500))
        _ = sampler.add(elapsed: .milliseconds(250), totalBytes: 1_000_000)
        _ = sampler.add(elapsed: .milliseconds(500), totalBytes: 2_000_000)

        let sample = sampler.add(elapsed: .milliseconds(750), totalBytes: 3_500_000)

        // The window starts at 0.25 s: 2.5 MB in 0.5 s.
        #expect(sample.currentMbps.isClose(to: 40))
    }
}

private extension Double {
    /// Rates are computed in floating point, so they're compared within a rounding error, not for equality.
    static let roundingTolerance = 1e-9

    func isClose(to other: Double) -> Bool {
        abs(self - other) < Self.roundingTolerance
    }
}
