//
//  Candidate.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// A server picked for pinging.
public struct Candidate: Sendable, Equatable, Identifiable {
    public let server: Server
    /// Meters from the device; `nil` in approximate mode, where there is no position to measure from.
    public let distance: Double?
    public var ping: PingState

    public var id: Server.ID {
        server.id
    }

    public init(server: Server, distance: Double?, ping: PingState = .pending) {
        self.server = server
        self.distance = distance
        self.ping = ping
    }
}
