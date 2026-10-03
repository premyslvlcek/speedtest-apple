//
//  TransferResult.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The outcome of one direction. A final result and a partial one are defined the same way: the last sample.
public struct TransferResult: Sendable, Equatable {
    public var averageMbps: Double
    /// Stopped or interrupted before the full duration.
    public var wasPartial: Bool

    public init(lastSample: ThroughputSample, wasPartial: Bool) {
        averageMbps = lastSample.averageMbps
        self.wasPartial = wasPartial
    }
}
