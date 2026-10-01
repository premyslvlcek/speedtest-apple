//
//  SpeedTestPresentationTests.swift
//  SpeedTestFeatureTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import ICMP
import SpeedTestKit
import Testing

@testable import SpeedTestFeature

/// What the screen shows in each state, as plain values; the views only turn them into text.
@MainActor
@Suite struct SpeedTestPresentationTests {
    @Test func idle() {
        let state = SpeedTest.State.idleFixture
        #expect(state.phaseLabel == .ready)
        #expect(state.bigNumber == nil)
        #expect(state.serverValue == .none)
        #expect(state.pingValue == .none)
        #expect(state.downloadValue == nil)
        #expect(state.uploadValue == .none)
        #expect(state.notes.isEmpty)
        #expect(state.failure == nil)
        #expect(state.buttonTitle == .start)
        #expect(state.showsIntroduction)
        #expect(!state.isApproximate)
    }

    @Test func pinging() {
        let state = SpeedTest.State.pingingFixture
        #expect(state.phaseLabel == .pinging(serverCount: 5))
        #expect(state.serverValue == .choosing)
        #expect(state.pingValue == .none)
        #expect(state.bigNumber == nil)
        #expect(state.buttonTitle == .stop)
        #expect(!state.showsIntroduction)
    }

    @Test func downloadingShowsTheLiveValue() throws {
        let state = SpeedTest.State.downloadingFixture
        let last = try #require(state.downloadSamples.last)
        let selection = try #require(state.selection)
        let ping = try #require(selection.ping)
        let median = try #require(ping.median)

        #expect(state.phaseLabel == .downloading(seconds: last.elapsed.inSeconds))
        #expect(state.bigNumber == last.currentMbps)
        #expect(state.downloadValue == .init(mbps: last.currentMbps, tag: nil))
        #expect(state.serverValue == .server(name: selection.server.name))
        #expect(state.pingValue == .result(
            milliseconds: median.inMilliseconds, received: ping.received, sent: ping.sent
        ))
        #expect(state.uploadValue == .none)
        #expect(state.buttonTitle == .stop)
    }

    @Test func uploadingShowsTheLiveUpload() throws {
        var state = SpeedTest.State.finishedFixture
        state.upload = nil
        state.uploadSamples = Array(SpeedTest.State.uploadSeries.prefix(8))
        state.phase = .uploading
        let last = try #require(state.uploadSamples.last)

        #expect(state.phaseLabel == .uploading(seconds: last.elapsed.inSeconds))
        #expect(state.bigNumber == last.currentMbps)
        #expect(state.downloadValue?.tag == .average)
        #expect(state.uploadValue == .speed(.init(mbps: last.currentMbps, tag: nil)))
    }

    @Test func finishedShowsTheDownloadAverage() throws {
        let state = SpeedTest.State.finishedFixture
        let download = try #require(state.download)
        let upload = try #require(state.upload)

        #expect(state.phaseLabel == .downloadAverage)
        #expect(state.bigNumber == download.averageMbps)
        #expect(state.downloadValue == .init(mbps: download.averageMbps, tag: .average))
        #expect(state.uploadValue == .speed(.init(mbps: upload.averageMbps, tag: .average)))
        #expect(state.buttonTitle == .runAgain)
    }

    @Test func stoppedDuringDownloadIsPartial() throws {
        let state = SpeedTest.State.stoppedFixture
        let download = try #require(state.download)
        let last = try #require(state.downloadSamples.last)

        #expect(state.phaseLabel == .stopped(atSeconds: last.elapsed.inSeconds))
        #expect(state.bigNumber == download.averageMbps)
        #expect(state.downloadValue == .init(mbps: download.averageMbps, tag: .partialAverage))
        #expect(state.uploadValue == .notRun)
        #expect(state.buttonTitle == .start)
    }

    @Test func stoppedDuringUploadKeepsTheDownloadAverage() throws {
        var state = SpeedTest.State.finishedFixture
        state.upload = nil
        state.uploadSamples = Array(SpeedTest.State.uploadSeries.prefix(8))
        state.phase = .uploading
        state.interrupt(.stopped)
        let upload = try #require(state.upload)

        #expect(state.phaseLabel == .stoppedAfterDownload)
        #expect(state.downloadValue?.tag == .average)
        #expect(state.uploadValue == .speed(.init(mbps: upload.averageMbps, tag: .partialAverage)))
    }

    /// Stop before any sample exists, as the screen shows it.
    @Test func stoppedWhilePingingShowsNoNumber() {
        var state = SpeedTest.State.pingingFixture
        state.interrupt(.stopped)

        #expect(state.phaseLabel == .stopped(atSeconds: nil))
        #expect(state.bigNumber == nil)
        #expect(state.downloadValue == nil)
        #expect(state.uploadValue == .notRun)
    }

    /// Every interruption other than Stop takes the same path; one stands for all.
    @Test func anInterruptionNamesTheReason() {
        var state = SpeedTest.State.downloadingFixture
        state.interrupt(.networkChanged)

        #expect(state.phaseLabel == .interrupted(.networkChanged))
        #expect(state.downloadValue?.tag == .partialAverage)
    }

    @Test func locationOffAndICMPBlocked() {
        let state = SpeedTest.State.degradedFixture

        #expect(state.notes == [.locationOff, .icmpBlocked])
        #expect(state.pingValue == .noReply)
        #expect(state.isApproximate)
    }

    @Test func locationUnavailableHasItsOwnNote() {
        var state = SpeedTest.State.downloadingFixture
        state.location = .unavailable

        #expect(state.notes == [.locationUnavailable])
        #expect(state.isApproximate)
    }

    @Test func failedShowsTheErrorAndTryAgain() {
        let state = SpeedTest.State.failedFixture

        #expect(state.phaseLabel == .failed)
        #expect(state.failure == .offline)
        #expect(state.buttonTitle == .tryAgain)
        #expect(state.bigNumber == nil)
    }

    @Test func uploadUnavailable() {
        var state = SpeedTest.State.finishedFixture
        state.upload = nil
        state.uploadSamples = []
        state.isUploadUnavailable = true

        #expect(state.uploadValue == .unavailable)
    }

    /// The label's elapsed time is swapped frame by frame while it counts; every other part must stay.
    @Test(arguments: [
        (SpeedTest.State.PhaseLabel.downloading(seconds: 7.25), SpeedTest.State.PhaseLabel.downloading(seconds: 7.4)),
        (.uploading(seconds: 2.5), .uploading(seconds: 7.4)),
        (.stopped(atSeconds: 3), .stopped(atSeconds: 7.4)),
        (.stopped(atSeconds: nil), .stopped(atSeconds: nil)),
        (.ready, .ready)
    ])
    func aLabelTakesAnotherElapsedTime(label: SpeedTest.State.PhaseLabel, expected: SpeedTest.State.PhaseLabel) {
        #expect(label.withSeconds(7.4) == expected)
    }
}
