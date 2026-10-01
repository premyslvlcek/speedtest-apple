//
//  SpeedTest+Text.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import DesignSystem
import SpeedTestKit
import SwiftUI

/// Turns the presentation values into localized text, through the String Catalog's generated symbols.
extension SpeedTest.State.PhaseLabel {
    var text: Text {
        switch self {
        case .connecting:
            Text(.phaseConnecting)

        case .downloadAverage:
            Text(.phaseDownloadAverage)

        case let .downloading(seconds):
            Text(.phaseDownloading(SpeedFormat.elapsed(seconds: seconds)))

        case .failed:
            Text(.phaseFailed)

        case .findingServers:
            Text(.phaseFindingServers)

        case let .interrupted(reason):
            reason.text

        case .locating:
            Text(.phaseLocating)

        case let .pinging(serverCount):
            Text(.phasePinging(serverCount))

        case .ready:
            Text(.phaseReady)

        case let .stopped(atSeconds: seconds?):
            Text(.phaseStoppedAt(SpeedFormat.elapsed(seconds: seconds)))

        case .stopped(atSeconds: nil):
            Text(.phaseStopped)

        case .stoppedAfterDownload:
            Text(.phaseStoppedAfterDownload)

        case let .uploading(seconds):
            Text(.phaseUploading(SpeedFormat.elapsed(seconds: seconds)))
        }
    }
}

extension SpeedTest.Interruption {
    var text: Text {
        switch self {
        case .background:
            Text(.phaseInterruptedBackground)

        case .connectionLost:
            Text(.phaseInterruptedConnectionLost)

        case .networkChanged:
            Text(.phaseInterruptedNetworkChanged)

        case .stopped:
            Text(.phaseStopped)
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
    var message: Text {
        switch self {
        case .connectionLost:
            Text(.errorConnectionLost)

        case .directoryUnavailable:
            Text(.errorDirectoryUnavailable)

        case .networkChanged:
            Text(.errorNetworkChanged)

        case .noServers:
            Text(.errorNoServers)

        case .offline:
            Text(.errorOffline)

        case .rateLimited:
            Text(.errorRateLimited)

        case .transferFailed:
            Text(.errorTransferFailed)
        }
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
            SpeedFormat.pingSummary(milliseconds: nil, received: 0, sent: 0)

        case let .result(milliseconds, received, sent):
            SpeedFormat.pingSummary(milliseconds: milliseconds, received: received, sent: sent)
        }
    }

    var downloadString: String {
        Self.speedString(downloadValue)
    }

    var downloadTag: String? {
        Self.tagString(downloadValue?.tag)
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

    var uploadTag: String? {
        guard case let .speed(value) = uploadValue else {
            return nil
        }

        return Self.tagString(value.tag)
    }

    private static func speedString(_ value: SpeedValue?) -> String {
        guard let value else {
            return SpeedFormat.placeholder
        }

        return String(localized: .valueSpeed(SpeedFormat.mbps(value.mbps)))
    }

    private static func tagString(_ tag: ValueTag?) -> String? {
        switch tag {
        case .average:
            String(localized: .tagAverage)

        case .none:
            nil

        case .partialAverage:
            String(localized: .tagPartialAverage)
        }
    }
}
