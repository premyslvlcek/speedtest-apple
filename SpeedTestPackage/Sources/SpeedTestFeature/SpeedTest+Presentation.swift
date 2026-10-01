//
//  SpeedTest+Presentation.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import ICMP
import SpeedTestKit

/// What the screen shows, as plain values. The views only turn these into text.
extension SpeedTest.State {
    enum PhaseLabel: Equatable, Sendable {
        case ready
        case locating
        case findingServers
        case pinging(serverCount: Int)
        case connecting
        case downloading(seconds: Double)
        case uploading(seconds: Double)
        case downloadAverage
        case stopped(atSeconds: Double?)
        case stoppedAfterDownload
        case interrupted(SpeedTest.Interruption)
        case failed
    }

    enum ValueTag: Equatable, Sendable {
        case average
        case partialAverage
    }

    struct SpeedValue: Equatable, Sendable {
        var mbps: Double
        var tag: ValueTag?
    }

    enum ServerValue: Equatable, Sendable {
        case none
        case choosing
        case server(name: String)
    }

    enum PingValue: Equatable, Sendable {
        case none
        case noReply
        case result(milliseconds: Double, received: Int, sent: Int)
    }

    enum UploadValue: Equatable, Sendable {
        case none
        case notRun
        case unavailable
        case speed(SpeedValue)
    }

    enum Note: Equatable, Hashable, Sendable {
        case locationOff
        case locationUnavailable
        case icmpBlocked
    }

    enum ButtonTitle: Equatable, Sendable {
        case start
        case stop
        case runAgain
        case tryAgain
    }

    var phaseLabel: PhaseLabel {
        switch phase {
        case .connecting:
            .connecting

        case .downloading:
            .downloading(seconds: downloadSamples.last?.elapsed.inSeconds ?? 0)

        case .failed:
            .failed

        case .fetchingServers:
            .findingServers

        case .finished:
            .downloadAverage

        case .idle:
            .ready

        case let .interrupted(reason):
            interruptionLabel(reason)

        case .locating:
            .locating

        case .pinging:
            .pinging(serverCount: candidates.count)

        case .uploading:
            .uploading(seconds: uploadSamples.last?.elapsed.inSeconds ?? 0)
        }
    }

    /// The live speed of the running phase; the download average once it's known and nothing else is live.
    var bigNumber: Double? {
        switch phase {
        case .downloading:
            downloadSamples.last?.currentMbps

        case .uploading:
            uploadSamples.last?.currentMbps

        case .connecting(.upload), .finished, .interrupted:
            download?.averageMbps

        case .connecting(.download), .failed, .fetchingServers, .idle, .locating, .pinging:
            nil
        }
    }

    var serverValue: ServerValue {
        if let selection {
            return .server(name: selection.server.name)
        }

        return phase == .pinging ? .choosing : .none
    }

    var pingValue: PingValue {
        guard let selection else {
            return .none
        }

        guard let ping = selection.ping, let median = ping.median else {
            return .noReply
        }

        return .result(milliseconds: median.inMilliseconds, received: ping.received, sent: ping.sent)
    }

    var downloadValue: SpeedValue? {
        if let download {
            return SpeedValue(mbps: download.averageMbps, tag: download.wasPartial ? .partialAverage : .average)
        }

        if phase == .downloading, let last = downloadSamples.last {
            return SpeedValue(mbps: last.currentMbps, tag: nil)
        }

        return nil
    }

    var uploadValue: UploadValue {
        if let upload {
            return .speed(SpeedValue(mbps: upload.averageMbps, tag: upload.wasPartial ? .partialAverage : .average))
        }

        if phase == .uploading, let last = uploadSamples.last {
            return .speed(SpeedValue(mbps: last.currentMbps, tag: nil))
        }

        if isUploadUnavailable {
            return .unavailable
        }

        if case .interrupted = phase, uploadSamples.isEmpty {
            return .notRun
        }

        return .none
    }

    var notes: [Note] {
        var notes: [Note] = []
        switch location {
        case .notAuthorized:
            notes.append(.locationOff)

        case .unavailable:
            notes.append(.locationUnavailable)

        case .located, .none:
            break
        }

        if selection?.reason == .icmpBlocked {
            notes.append(.icmpBlocked)
        }
        return notes
    }

    var failure: SpeedTestError? {
        guard case let .failed(error) = phase else {
            return nil
        }

        return error
    }

    var buttonTitle: ButtonTitle {
        if isRunning {
            return .stop
        }

        switch phase {
        case .finished:
            return .runAgain

        case .failed:
            return .tryAgain

        case .connecting, .downloading, .fetchingServers, .idle, .interrupted, .locating, .pinging, .uploading:
            return .start
        }
    }

    var showsIntroduction: Bool {
        phase == .idle
    }

    var isApproximate: Bool {
        location == .notAuthorized || location == .unavailable
    }

    private func interruptionLabel(_ reason: SpeedTest.Interruption) -> PhaseLabel {
        guard reason == .stopped else {
            return .interrupted(reason)
        }

        if let download, !download.wasPartial {
            return .stoppedAfterDownload
        }

        return .stopped(atSeconds: downloadSamples.last?.elapsed.inSeconds)
    }
}

extension SpeedTest.State.PhaseLabel {
    /// The elapsed time a label shows, if it shows one.
    var seconds: Double? {
        switch self {
        case let .downloading(seconds), let .uploading(seconds):
            seconds

        case let .stopped(atSeconds: seconds):
            seconds

        case .connecting, .downloadAverage, .failed, .findingServers, .interrupted, .locating, .pinging, .ready,
             .stoppedAfterDownload:
            nil
        }
    }

    /// The same label with another elapsed time, for drawing the in-between frames of a count.
    func withSeconds(_ seconds: Double) -> Self {
        switch self {
        case .downloading:
            .downloading(seconds: seconds)

        case .uploading:
            .uploading(seconds: seconds)

        case .stopped(atSeconds: .some):
            .stopped(atSeconds: seconds)

        case .connecting, .downloadAverage, .failed, .findingServers, .interrupted, .locating, .pinging, .ready,
             .stopped(atSeconds: .none), .stoppedAfterDownload:
            self
        }
    }
}

extension Duration {
    var inMilliseconds: Double {
        inSeconds * 1000
    }
}
