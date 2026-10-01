//
//  SpeedChart.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import Charts
import SwiftUI

public struct ChartPoint: Sendable, Equatable, Identifiable {
    public var seconds: Double
    public var mbps: Double

    public var id: Double {
        seconds
    }

    public init(seconds: Double, mbps: Double) {
        self.seconds = seconds
        self.mbps = mbps
    }
}

/// The live speed graph: an area under a line, over a fixed time axis, with an optional dashed average.
/// Decorative for VoiceOver: the big number above it carries the same information.
public struct SpeedChart: View {
    private let points: [ChartPoint]
    private let average: Double?
    private let duration: Double
    private let tint: Color

    public init(points: [ChartPoint], average: Double?, duration: Double, tint: Color) {
        self.points = points
        self.average = average
        self.duration = duration
        self.tint = tint
    }

    public var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Time", point.seconds),
                    y: .value("Speed", point.mbps)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.35), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", point.seconds),
                    y: .value("Speed", point.mbps)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            // A ForEach over zero or one value instead of `if let`: conditional chart content produced
            // warnings and crashes with deployment targets below 27 in the iOS 27 betas.
            ForEach(averageLine, id: \.self) { value in
                RuleMark(y: .value("Average", value))
                    .foregroundStyle(tint.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXScale(domain: 0 ... max(duration, 0.1))
        .chartYScale(domain: 0 ... Self.upperBound(points: points, average: average))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
        }
        // At least the old fixed height; it may grow, so axis labels at large text sizes aren't clipped.
        .frame(minHeight: 120, maxHeight: 160)
        .accessibilityHidden(true)
    }

    private var averageLine: [Double] {
        average.map { [$0] } ?? []
    }

    /// 15 % headroom above the highest point or the average line, and never an empty range.
    static func upperBound(points: [ChartPoint], average: Double?) -> Double {
        let highest = max(points.map(\.mbps).max() ?? 0, average ?? 0)
        return highest > 0 ? highest * 1.15 : 1
    }
}

#Preview {
    SpeedChart(
        points: (1 ... 60).map { ChartPoint(seconds: Double($0) / 4, mbps: 480 * (1 - exp(-Double($0) / 8))) },
        average: 430,
        duration: 15,
        tint: Palette.download
    )
    .padding()
}
