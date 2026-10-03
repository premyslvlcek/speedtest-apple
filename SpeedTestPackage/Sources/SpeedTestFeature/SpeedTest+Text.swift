//
//  SpeedTest+Text.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import DesignSystem
import ICMP
import SpeedTestKit
import SwiftUI

/// Turns the presentation values into localized text, through the String Catalog's generated symbols.
extension SpeedTest.State.PhaseLabel {
    var resource: LocalizedStringResource {
        switch self {
        case .connecting:
            .phaseConnecting

        case .downloadAverage:
            .phaseDownloadAverage

        case let .downloading(seconds):
            .phaseDownloading(SpeedFormat.elapsed(seconds: seconds))

        case .failed:
            .phaseFailed

        case .findingServers:
            .phaseFindingServers

        case let .interrupted(reason, average: nil):
            reason.resource

        case let .interrupted(reason, average: .partialDownload):
            .phaseInterruptedPartialAverage(String(localized: reason.resource))

        case let .interrupted(reason, average: .download):
            .phaseInterruptedDownloadAverage(String(localized: reason.resource))

        case .locating:
            .phaseLocating

        case let .pinging(serverCount):
            .phasePinging(serverCount)

        case .ready:
            .phaseReady

        case let .stopped(atSeconds: seconds?):
            .phaseStoppedAt(SpeedFormat.elapsed(seconds: seconds))

        case .stopped(atSeconds: nil):
            .phaseStopped

        case .stoppedAfterDownload:
            .phaseStoppedAfterDownload

        case let .uploading(seconds):
            .phaseUploading(SpeedFormat.elapsed(seconds: seconds))
        }
    }

    var text: Text {
        Text(resource)
    }
}

extension SpeedTest.Interruption {
    var resource: LocalizedStringResource {
        switch self {
        case .background:
            .phaseInterruptedBackground

        case .connectionLost:
            .phaseInterruptedConnectionLost

        case .networkChanged:
            .phaseInterruptedNetworkChanged

        case .stopped:
            .phaseStopped
        }
    }
}

extension SpeedTest.State.Note {
    var text: Text {
        switch self {
        case .icmpBlocked:
            Text(.noteIcmpBlocked)

        case .locationOff:
            Text(.noteLocationOff)

        case .locationUnavailable:
            Text(.noteLocationUnavailable)
        }
    }

    var systemImage: String {
        switch self {
        case .icmpBlocked:
            "wifi.exclamationmark"

        case .locationOff, .locationUnavailable:
            "location.slash"
        }
    }
}

extension SpeedTestError {
    var messageResource: LocalizedStringResource {
        switch self {
        case .connectionLost:
            .errorConnectionLost

        case .directoryUnavailable:
            .errorDirectoryUnavailable

        case .networkChanged:
            .errorNetworkChanged

        case .noServers:
            .errorNoServers

        case .offline:
            .errorOffline

        case .rateLimited:
            .errorRateLimited

        case .transferFailed:
            .errorTransferFailed
        }
    }

    var message: Text {
        Text(messageResource)
    }
}

extension PingResult {
    /// "6 ms", "6 ms · 3/5" or "no reply", as a servers row shows it.
    var summary: String {
        SpeedFormat.pingSummary(milliseconds: median?.inMilliseconds, received: received, sent: sent)
    }

    /// The same as VoiceOver reads it: "6 ms, 3 of 5 replies".
    var spokenSummary: String {
        SpeedFormat.spokenPingSummary(milliseconds: median?.inMilliseconds, received: received, sent: sent)
    }
}

extension SpeedTest.State {
    var serverString: String {
        switch serverValue {
        case .choosing:
            String(localized: .valueChoosing)

        case .none:
            SpeedFormat.placeholder

        case let .server(name):
            name
        }
    }

    var pingString: String {
        switch pingValue {
        case .none:
            SpeedFormat.placeholder

        case .noReply:
            SpeedFormat.noReply()

        case let .result(milliseconds, received, sent):
            SpeedFormat.pingSummary(milliseconds: milliseconds, received: received, sent: sent)
        }
    }

    /// The Ping row as VoiceOver reads it: "3 of 5 replies", not "3/5".
    var spokenPing: String? {
        guard case let .result(milliseconds, received, sent) = pingValue else {
            return nil
        }

        return SpeedFormat.spokenPingSummary(milliseconds: milliseconds, received: received, sent: sent)
    }

    var downloadString: String {
        Self.speedString(downloadValue)
    }

    var downloadTag: ResultTag? {
        Self.tag(downloadValue?.tag)
    }

    var uploadString: String {
        switch uploadValue {
        case .none:
            SpeedFormat.placeholder

        case .notRun:
            String(localized: .valueNotRun)

        case let .speed(value):
            Self.speedString(value)

        case .unavailable:
            String(localized: .valueUnavailable)
        }
    }

    var uploadTag: ResultTag? {
        guard case let .speed(value) = uploadValue else {
            return nil
        }

        return Self.tag(value.tag)
    }

    /// "232 Mbps": a speed field's text for any value, so the field can count through the values in between.
    static func speedString(mbps: Double) -> String {
        String(localized: .valueSpeed(SpeedFormat.mbps(mbps)))
    }

    private static func speedString(_ value: SpeedValue?) -> String {
        guard let value else {
            return SpeedFormat.placeholder
        }

        return speedString(mbps: value.mbps)
    }

    private static func tag(_ tag: ValueTag?) -> ResultTag? {
        switch tag {
        case .average:
            ResultTag(text: String(localized: .tagAverage), spokenText: String(localized: .accessibilityTagAverage))

        case .none:
            nil

        case .partialAverage:
            ResultTag(
                text: String(localized: .tagPartialAverage),
                spokenText: String(localized: .accessibilityTagPartialAverage)
            )
        }
    }
}

extension SpeedTest.State {
    /// What VoiceOver says once, when a run ends: the result, why it stopped (with what was measured), or what went
    /// wrong. Nothing while a run is going or before the first one.
    var announcement: String? {
        switch phase {
        case .finished:
            results.isEmpty ? nil : results.joined(separator: ". ")

        case .interrupted:
            ([String(localized: phaseLabel.resource)] + results).joined(separator: ". ")

        case let .failed(error):
            [String(localized: phaseLabel.resource), String(localized: error.messageResource)].joined(separator: ". ")

        case .connecting, .downloading, .fetchingServers, .idle, .locating, .pinging, .uploading:
            nil
        }
    }

    private var results: [String] {
        var results: [String] = []
        if let download {
            results.append(String(localized: .accessibilityDownloadAverage(SpeedFormat.mbps(download.averageMbps))))
        }
        if let upload {
            results.append(String(localized: .accessibilityUploadAverage(SpeedFormat.mbps(upload.averageMbps))))
        }
        return results
    }
}
