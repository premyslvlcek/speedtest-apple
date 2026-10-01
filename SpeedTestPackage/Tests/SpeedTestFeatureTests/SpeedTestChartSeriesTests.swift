//
//  SpeedTestChartSeriesTests.swift
//  SpeedTestFeatureTests
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import DesignSystem
import SpeedTestKit
import Testing

@testable import SpeedTestFeature

/// Which samples the chart draws: the running transfer's, then the download with its average.
@MainActor
@Suite struct SpeedTestChartSeriesTests {
    @Test func noChartBeforeATransfer() {
        #expect(SpeedTest.State.pingingFixture.chartSeries == nil)
    }

    @Test func downloadingDrawsTheLiveDownload() throws {
        let state = SpeedTest.State.downloadingFixture
        let series = try #require(state.chartSeries)
        let last = try #require(state.downloadSamples.last)

        #expect(series.direction == .download)
        #expect(series.average == nil)
        #expect(series.duration == 15)
        #expect(series.points.count == state.downloadSamples.count)
        #expect(series.points.last == ChartPoint(seconds: last.elapsed.inSeconds, mbps: last.currentMbps))
    }

    @Test func uploadingDrawsTheLiveUpload() throws {
        var state = SpeedTest.State.finishedFixture
        state.upload = nil
        state.uploadSamples = Array(SpeedTest.State.uploadSeries.prefix(8))
        state.phase = .uploading
        let series = try #require(state.chartSeries)

        #expect(series.direction == .upload)
        #expect(series.duration == 10)
        #expect(series.points.count == 8)
        #expect(series.average == nil)
    }

    @Test func finishedDrawsTheDownloadWithItsAverage() throws {
        let state = SpeedTest.State.finishedFixture
        let series = try #require(state.chartSeries)

        #expect(series.direction == .download)
        #expect(series.points.count == state.downloadSamples.count)
        #expect(series.average == state.download?.averageMbps)
    }

    @Test func stoppedBeforeAnySampleHasNoChart() {
        var state = SpeedTest.State.pingingFixture
        state.interrupt(.stopped)

        #expect(state.chartSeries == nil)
    }
}
