//
//  TransferResult.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The outcome of one direction. A final result and a partial one are defined the same way: the last sample.
public struct TransferResult: Sendable, Equatable {
    public var averageMbps: Double
    public var totalBytes: Int64
    public var duration: Duration
    /// Stopped or interrupted before the full duration.
    public var wasPartial: Bool

    public init(averageMbps: Double, totalBytes: Int64, duration: Duration, wasPartial: Bool) {
        self.averageMbps = averageMbps
        self.totalBytes = totalBytes
        self.duration = duration
        self.wasPartial = wasPartial
    }

    public init(lastSample: ThroughputSample, wasPartial: Bool) {
        self.init(
            averageMbps: lastSample.averageMbps,
            totalBytes: lastSample.totalBytes,
            duration: lastSample.elapsed,
            wasPartial: wasPartial
        )
    }
}
