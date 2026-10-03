//
//  SpeedTestPresentationTests.swift
//  SpeedTestFeatureTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import DesignSystem
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
        #expect(!state.isApproximate)
    }

    @Test func pinging() {
        let state = SpeedTest.State.pingingFixture
        #expect(state.phaseLabel == .pinging(serverCount: 5))
        #expect(state.serverValue == .choosing)
        #expect(state.pingValue == .none)
        #expect(state.bigNumber == nil)
        #expect(state.buttonTitle == .stop)
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
        #expect(state.buttonTitle == .runAgain)
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
        #expect(state.uploadValue == .none)
    }

    /// Every interruption other than Stop takes the same path; one reason stands for all. The label says which
    /// average the big number shows, if any.
    @Test func anInterruptionNamesTheReasonAndTheAverage() {
        var downloading = SpeedTest.State.downloadingFixture
        downloading.interrupt(.networkChanged)
        #expect(downloading.phaseLabel == .interrupted(.networkChanged, average: .partialDownload))
        #expect(downloading.downloadValue?.tag == .partialAverage)

        var uploading = SpeedTest.State.finishedFixture
        uploading.upload = nil
        uploading.uploadSamples = Array(SpeedTest.State.uploadSeries.prefix(8))
        uploading.phase = .uploading
        uploading.interrupt(.networkChanged)
        #expect(uploading.phaseLabel == .interrupted(.networkChanged, average: .download))

        var pinging = SpeedTest.State.pingingFixture
        pinging.interrupt(.networkChanged)
        #expect(pinging.phaseLabel == .interrupted(.networkChanged, average: nil))
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

    /// The download average stays in its row; under "Connecting…" it would read as the upload's speed.
    @Test func whileTheUploadConnectsTheBigNumberIsEmpty() {
        var state = SpeedTest.State.finishedFixture
        state.upload = nil
        state.uploadSamples = []
        state.phase = .connecting(.upload)

        #expect(state.phaseLabel == .connecting)
        #expect(state.bigNumber == nil)
        #expect(state.downloadValue?.tag == .average)
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
        (.stopped(atSeconds: nil), .stopped(atSeconds: nil))
    ])
    func aLabelTakesAnotherElapsedTime(label: SpeedTest.State.PhaseLabel, expected: SpeedTest.State.PhaseLabel) {
        #expect(label.withSeconds(7.4) == expected)
    }

    // MARK: - What VoiceOver announces when a run ends

    @Test func aFinishedRunAnnouncesBothAverages() throws {
        let state = SpeedTest.State.finishedFixture
        let download = try #require(state.download)
        let upload = try #require(state.upload)

        #expect(state.announcement == [
            String(localized: .accessibilityDownloadAverage(SpeedFormat.mbps(download.averageMbps))),
            String(localized: .accessibilityUploadAverage(SpeedFormat.mbps(upload.averageMbps)))
        ].joined(separator: ". "))
    }

    @Test func anInterruptedRunAnnouncesWhyAndWhatWasMeasured() throws {
        let state = SpeedTest.State.stoppedFixture
        let download = try #require(state.download)

        #expect(state.announcement == [
            String(localized: state.phaseLabel.resource),
            String(localized: .accessibilityDownloadAverage(SpeedFormat.mbps(download.averageMbps)))
        ].joined(separator: ". "))
    }

    @Test func aFailedRunAnnouncesWhatWentWrong() {
        let state = SpeedTest.State.failedFixture

        #expect(state.announcement == [
            String(localized: state.phaseLabel.resource),
            String(localized: SpeedTestError.offline.messageResource)
        ].joined(separator: ". "))
    }

    @Test func nothingIsAnnouncedDuringARun() {
        #expect(SpeedTest.State.downloadingFixture.announcement == nil)
    }
}
