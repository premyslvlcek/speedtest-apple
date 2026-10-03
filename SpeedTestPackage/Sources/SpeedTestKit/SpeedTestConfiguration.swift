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
    public let locationTimeout: Duration = .seconds(10)
    public let directoryTimeout: Duration = .seconds(10)
    /// Candidates with a location.
    public let nearestCount = 5
    /// Candidates in approximate mode, where latency decides.
    public let approximateCount = 10
    public let ping = PingConfiguration.standard
    /// Servers with at least this many replies rank first.
    public let minimumReplies = 3
    public let downloadDuration: Duration = .seconds(15)
    /// Shorter than the download, to keep a whole run under about 30 s.
    public let uploadDuration: Duration = .seconds(10)
    /// Left out of the upload's samples and average: `URLSession` counts upload bytes ahead of the line (DESIGN §4).
    public let uploadWarmUp: Duration = .seconds(1)
    public let sampleInterval: Duration = .milliseconds(250)
    public let speedWindow: Duration = .seconds(1)
    /// No first byte after this long means failover. DNS, TCP, TLS and the request take about four round trips,
    /// which is over 2 s on a satellite link.
    public let stallTimeout: Duration = .seconds(5)
    public let transfer = TransferConfiguration()

    public init() {}

    public static let standard = SpeedTestConfiguration()
}
