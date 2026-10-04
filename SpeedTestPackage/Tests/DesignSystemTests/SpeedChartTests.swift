//
//  SpeedChartTests.swift
//  DesignSystemTests
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import Testing

@testable import DesignSystem

@Suite struct SpeedChartTests {
    /// 15 % headroom, rounded up to a round number, so the axis changes rarely instead of on every sample.
    @Test func upperBoundIsARoundNumberAboveTheHighestValue() {
        let points = [100.0, 236, 180].enumerated().map { ChartPoint(seconds: Double($0.offset), mbps: $0.element) }

        // 236 × 1.15 = 271.4 → 300.
        #expect(SpeedChart.upperBound(points: points, average: nil) == 300)
    }

    @Test func upperBoundMakesRoomForTheAverageLine() {
        let points = [ChartPoint(seconds: 0.25, mbps: 100)]

        // 300 × 1.15 = 345 → 400.
        #expect(SpeedChart.upperBound(points: points, average: 300) == 400)
    }

    /// A value that lands exactly on a round step stays there, even when the headroom arithmetic leaves it a
    /// rounding error above: 1500 / 1.15 × 1.15 is 1500.0000000000002, which must give 1500, not 2000.
    @Test func aValueOnARoundStepStaysOnIt() {
        let points = [ChartPoint(seconds: 0.25, mbps: 1500 / 1.15)]

        #expect(SpeedChart.upperBound(points: points, average: nil) == 1500)
    }

    /// An empty or all-zero series still needs a range: a 0…0 scale can't be drawn.
    @Test func upperBoundIsNeverZero() {
        #expect(SpeedChart.upperBound(points: [ChartPoint(seconds: 0.25, mbps: 0)], average: 0) == 1)
    }

    /// The line starts at the left edge: an upload's first sample comes after its 1 s warm-up, not at zero.
    @Test func theTimeAxisStartsAtTheFirstPoint() {
        let points = [ChartPoint(seconds: 1.25, mbps: 90), ChartPoint(seconds: 1.5, mbps: 92)]

        #expect(SpeedChart.timeDomain(points: points, duration: 10) == 1.25 ... 10)
        #expect(SpeedChart.timeDomain(points: [], duration: 10) == 0 ... 10)
    }

    /// While the chart animates, its newest point is drawn at the in-between position; the others stay put.
    @Test func theNewestPointIsDrawnAtTheAnimatedHead() {
        let points = [ChartPoint(seconds: 0.25, mbps: 100), ChartPoint(seconds: 0.5, mbps: 200)]

        let drawn = SpeedChart.drawnPoints(points, head: ChartPoint(seconds: 0.4, mbps: 160))

        #expect(drawn == [ChartPoint(seconds: 0.25, mbps: 100), ChartPoint(seconds: 0.4, mbps: 160)])
    }

    /// When a sample arrives, the head starts where the previous point is. Two points at the same time make the
    /// smoothed curve overshoot far above the plot, so the point the head is leaving isn't drawn twice.
    @Test func thePointTheHeadIsLeavingIsNotDrawnTwice() {
        let points = [
            ChartPoint(seconds: 0.25, mbps: 100),
            ChartPoint(seconds: 0.5, mbps: 200),
            ChartPoint(seconds: 0.75, mbps: 260)
        ]

        let drawn = SpeedChart.drawnPoints(points, head: ChartPoint(seconds: 0.5, mbps: 200))

        #expect(drawn == [ChartPoint(seconds: 0.25, mbps: 100), ChartPoint(seconds: 0.5, mbps: 200)])
    }
}
