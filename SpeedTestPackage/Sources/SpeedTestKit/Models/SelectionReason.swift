//
//  SelectionReason.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// Why this server is the one being measured.
public enum SelectionReason: Sendable, Equatable {
    /// It had the best ping.
    case lowestPing
    /// No server answered ICMP, so the nearest one is used. Never an HTTP ping instead.
    case icmpBlocked
    /// The first choice failed before its first byte.
    case failover
}
