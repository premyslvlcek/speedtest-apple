//
//  RecordingPingService.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ConcurrencyExtras
import ICMP
import SpeedTestKit

/// Answers pings from a table keyed by host and records which hosts were pinged.
final class RecordingPingService: Sendable {
    static let fullReply = PingResult(rtts: Array(repeating: .milliseconds(10), count: 5), sent: 5)

    private let results: [String: PingResult]
    private let fallback: PingResult
    private let hosts = LockIsolated<[String]>([])

    init(results: [String: PingResult] = [:], fallback: PingResult = RecordingPingService.fullReply) {
        self.results = results
        self.fallback = fallback
    }

    var pingedHosts: [String] {
        hosts.value
    }

    var service: PingService {
        PingService(ping: { host, _ in
            self.hosts.withValue { $0.append(host) }
            return self.results[host] ?? self.fallback
        })
    }
}
