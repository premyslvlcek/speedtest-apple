//
//  TransferMeter.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import DependenciesMacros

/// Measures one transfer: waits for the first byte (t0), then samples it every `sampleInterval` until
/// t0 + the direction's duration.
@DependencyClient
public struct TransferMeter: Sendable {
    /// A sample every `sampleInterval` from t0; the last one at exactly t0 + the duration, then the stream finishes.
    /// It fails only with a `SpeedTestError`. Ending the iteration (Stop) cancels the transfer.
    public var measure: @Sendable (_ server: Server, _ direction: TransferDirection, _ token: TransferToken)
        -> AsyncThrowingStream<ThroughputSample, any Error> = { _, _, _ in AsyncThrowingStream { $0.finish() } }
}

public extension DependencyValues {
    @DependencyEntry(liveValue: TransferMeter.live)
    var transferMeter = TransferMeter()
}
