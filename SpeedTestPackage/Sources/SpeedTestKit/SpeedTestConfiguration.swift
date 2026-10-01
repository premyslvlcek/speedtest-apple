//
//  SpeedTestConfiguration.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ICMP

/// The numbers that shape a run: timeouts, counts, durations and sampling. Transfer and ping details sit in
/// `TransferConfiguration` and `PingConfiguration`, which this holds.
public struct SpeedTestConfiguration: Sendable, Equatable {
    /// Starts only once location permission is resolved, so the user reading the dialog never times out.
    public var locationTimeout: Duration = .seconds(10)
    public var directoryTimeout: Duration = .seconds(10)
    /// Candidates with a location.
    public var nearestCount = 5
    /// Candidates in approximate mode, where latency decides.
    public var approximateCount = 10
    public var ping = PingConfiguration.standard
    /// Servers with at least this many replies rank first.
    public var minimumReplies = 3
    public var downloadDuration: Duration = .seconds(15)
    /// Shorter than the download, to keep a whole run under about 30 s.
    public var uploadDuration: Duration = .seconds(10)
    public var sampleInterval: Duration = .milliseconds(250)
    public var speedWindow: Duration = .seconds(1)
    /// No first byte after this long means failover.
    public var stallTimeout: Duration = .seconds(3)
    public var transfer = TransferConfiguration()

    public init() {}

    public static let standard = SpeedTestConfiguration()
}
