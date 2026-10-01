//
//  PingService.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import DependenciesMacros
import ICMP

/// Sends ICMP echo requests to one host and reports the round-trip times.
@DependencyClient
public struct PingService: Sendable {
    public var ping: @Sendable (_ host: String, _ configuration: PingConfiguration) async -> PingResult
        = { _, configuration in .noReply(sent: configuration.count) }
}

public extension DependencyValues {
    @DependencyEntry(liveValue: PingService.live)
    var pingService = PingService()
}
