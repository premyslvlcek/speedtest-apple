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

    /// Round numbers in every decade, so a slow line gets as fitting an axis as a fast one.
    @Test(arguments: [(7.0, 8.0), (115.0, 150.0), (1300.0, 1500.0)])
    func upperBoundRoundsWithinItsDecade(highest: Double, expected: Double) {
        let points = [ChartPoint(seconds: 0.25, mbps: highest / 1.15)]

        #expect(SpeedChart.upperBound(points: points, average: nil) == expected)
    }

    /// An empty or all-zero series still needs a range: a 0…0 scale can't be drawn.
    @Test func upperBoundIsNeverZero() {
        #expect(SpeedChart.upperBound(points: [ChartPoint(seconds: 0.25, mbps: 0)], average: 0) == 1)
    }

    /// While the chart animates, its newest point is drawn at the in-between position; the others stay put.
    @Test func theNewestPointIsDrawnAtTheAnimatedHead() {
        let points = [ChartPoint(seconds: 0.25, mbps: 100), ChartPoint(seconds: 0.5, mbps: 200)]

        let drawn = SpeedChart.drawnPoints(points, head: ChartPoint(seconds: 0.4, mbps: 160))

        #expect(drawn == [ChartPoint(seconds: 0.25, mbps: 100), ChartPoint(seconds: 0.4, mbps: 160)])
    }
}
