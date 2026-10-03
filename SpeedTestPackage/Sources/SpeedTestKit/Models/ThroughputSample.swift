//
//  ThroughputSample.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// One reading of a transfer, emitted every sample interval after the first byte.
public struct ThroughputSample: Sendable, Equatable {
    /// Time since the first byte (t0).
    public var elapsed: Duration
    public var totalBytes: Int64
    /// Over the last second, or since t0 when that's shorter.
    public var currentMbps: Double
    /// Bytes over time since t0, or since the end of the upload's warm-up; measured at the real time of the reading,
    /// which `elapsed` may round down to the duration.
    public var averageMbps: Double

    public init(elapsed: Duration, totalBytes: Int64, currentMbps: Double, averageMbps: Double) {
        self.elapsed = elapsed
        self.totalBytes = totalBytes
        self.currentMbps = currentMbps
        self.averageMbps = averageMbps
    }
}
