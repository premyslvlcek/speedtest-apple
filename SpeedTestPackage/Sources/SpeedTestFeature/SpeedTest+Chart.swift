//
//  SpeedTest+Chart.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import DesignSystem
import SpeedTestKit

extension SpeedTest.State {
    struct ChartSeries: Equatable, Sendable {
        var points: [ChartPoint]
        var average: Double?
        var duration: Double
        var direction: TransferDirection
    }

    /// The running phase's live samples; once the run ends, the download with its average.
    var chartSeries: ChartSeries? {
        let configuration = SpeedTestConfiguration.standard

        switch phase {
        case .connecting(.download), .downloading:
            return ChartSeries(
                points: Self.points(downloadSamples),
                average: nil,
                duration: configuration.downloadDuration.inSeconds,
                direction: .download
            )

        case .connecting(.upload), .uploading:
            return ChartSeries(
                points: Self.points(uploadSamples),
                average: nil,
                duration: configuration.uploadDuration.inSeconds,
                direction: .upload
            )

        case .finished, .interrupted:
            guard !downloadSamples.isEmpty else {
                return nil
            }

            return ChartSeries(
                points: Self.points(downloadSamples),
                average: download?.averageMbps,
                duration: configuration.downloadDuration.inSeconds,
                direction: .download
            )

        case .failed, .fetchingServers, .idle, .locating, .pinging:
            return nil
        }
    }

    private static func points(_ samples: [ThroughputSample]) -> [ChartPoint] {
        samples.map { ChartPoint(seconds: $0.elapsed.inSeconds, mbps: $0.currentMbps) }
    }
}
