//
//  SpeedChartTests.swift
//  DesignSystemTests
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import Testing

@testable import DesignSystem

@Suite struct SpeedChartTests {
    @Test func upperBoundLeavesHeadroomAboveTheHighestValue() {
        let points = [100.0, 400, 250].enumerated().map { ChartPoint(seconds: Double($0.offset), mbps: $0.element) }

        #expect(abs(SpeedChart.upperBound(points: points, average: nil) - 460) < 0.001)
    }

    @Test func upperBoundMakesRoomForTheAverageLine() {
        let points = [ChartPoint(seconds: 0.25, mbps: 100)]

        #expect(abs(SpeedChart.upperBound(points: points, average: 300) - 345) < 0.001)
    }

    /// An empty or all-zero series still needs a range: a 0…0 scale can't be drawn.
    @Test func upperBoundIsNeverZero() {
        #expect(SpeedChart.upperBound(points: [ChartPoint(seconds: 0.25, mbps: 0)], average: 0) == 1)
    }
}
