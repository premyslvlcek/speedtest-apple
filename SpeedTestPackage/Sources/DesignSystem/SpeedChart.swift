//
//  SpeedChart.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import Charts
import SwiftUI

public struct ChartPoint: Sendable, Equatable {
    public var seconds: Double
    public var mbps: Double

    public init(seconds: Double, mbps: Double) {
        self.seconds = seconds
        self.mbps = mbps
    }
}

/// The live speed graph: an area under a line, from the first point to the end of the transfer, with an optional
/// dashed average.
/// Decorative for VoiceOver: the big number above it carries the same information.
///
/// Inside an animation the newest point moves from the previous sample to the new one frame by frame, so the line
/// grows toward each sample instead of jumping to it.
public struct SpeedChart: View, Animatable {
    private let points: [ChartPoint]
    private let average: Double?
    private let duration: Double
    private let tint: Color
    /// Where the newest point is drawn: the newest sample, or a step on the way to it while animating.
    private var head: AnimatablePair<Double, Double>

    public init(points: [ChartPoint], average: Double?, duration: Double, tint: Color) {
        self.points = points
        self.average = average
        self.duration = duration
        self.tint = tint
        head = AnimatablePair(points.last?.seconds ?? 0, points.last?.mbps ?? 0)
    }

    public var animatableData: AnimatablePair<Double, Double> {
        get { head }
        set { head = newValue }
    }

    public var body: some View {
        // Identified by position: the newest point's time changes on every frame of the animation.
        let current = ChartPoint(seconds: head.first, mbps: head.second)
        let drawn = Array(Self.drawnPoints(points, head: current).enumerated())
        return Chart {
            ForEach(drawn, id: \.offset) { _, point in
                AreaMark(
                    x: .value(Text(.chartTime), point.seconds),
                    y: .value(Text(.chartSpeed), point.mbps)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.35), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // The gradient spans the fixed plot area, not the area mark's own bounds: those change on every
                // frame while the newest point moves, and a gradient resized with them flickers.
                .alignsMarkStylesWithPlotArea()
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value(Text(.chartTime), point.seconds),
                    y: .value(Text(.chartSpeed), point.mbps)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            // A ForEach over zero or one value instead of `if let`: with the iOS 27 SDK and a deployment target
            // below 27, conditional chart content warned and crashed (seen in the betas; CI still builds with it).
            ForEach(averageLine, id: \.self) { value in
                RuleMark(y: .value(Text(.chartAverage), value))
                    .foregroundStyle(tint.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXScale(domain: Self.timeDomain(points: points, duration: duration))
        .chartYScale(domain: 0 ... Self.upperBound(points: points, average: average))
        // Only the head point animates (`animatableData`); Charts' own animation of every mark would fight it.
        .transaction { $0.animation = nil }
        // Nothing is drawn outside the plot, whatever the curve does between two points.
        .chartPlotStyle { $0.clipped() }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
        }
        // Before the first point there's no scale worth showing (it would read 0 to 1 Mbps).
        .chartYAxis(points.isEmpty ? .hidden : .automatic)
        // Fixed, so the card below never moves; the axis labels stop growing at xxxLarge to fit it.
        .frame(height: Self.height)
        .accessibilityHidden(true)
    }

    /// The chart's height, and the empty space the screen keeps for it when there's no chart.
    public static let height: CGFloat = 140

    /// The points as drawn: the newest one replaced by the animated head. A point at or after the head's time is
    /// left out: when a sample arrives the head starts where the previous point is, and two points at the same time
    /// make the smoothed curve overshoot far above the plot.
    nonisolated static func drawnPoints(_ points: [ChartPoint], head: ChartPoint) -> [ChartPoint] {
        guard !points.isEmpty else {
            return []
        }

        return points.dropLast().filter { $0.seconds < head.seconds } + [head]
    }

    /// From the first point to the end of the transfer, so the line starts at the left edge. The first sample comes
    /// one interval after the first byte, and an upload's first comes after its warm-up: from zero, the graph would
    /// start with a gap. Before the first point, from zero. Never an empty range.
    nonisolated static func timeDomain(points: [ChartPoint], duration: Double) -> ClosedRange<Double> {
        let start = points.first?.seconds ?? 0
        return start ... max(duration, start + 0.1)
    }

    private var averageLine: [Double] {
        average.map { [$0] } ?? []
    }

    /// 15 % headroom above the highest point or the average line, rounded up to a round number (… 150, 200, 250,
    /// 300, 400 …). During a transfer points are only added, so the axis only ever steps up, and rarely: it doesn't
    /// rescale the chart on every sample. Never an empty range.
    nonisolated static func upperBound(points: [ChartPoint], average: Double?) -> Double {
        let highest = max(points.map(\.mbps).max() ?? 0, average ?? 0) * 1.15
        guard highest > 0 else {
            return 1
        }

        let magnitude = pow(10, log10(highest).rounded(.down))
        let roundSteps: [Double] = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]
        let step = roundSteps.first { highest <= $0 * magnitude * (1 + 1e-9) } ?? 10
        return step * magnitude
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
