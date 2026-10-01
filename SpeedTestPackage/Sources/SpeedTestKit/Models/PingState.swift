//
//  PingState.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ICMP

/// A candidate's ping, as the Closest servers list shows it: a spinner until the result arrives.
public enum PingState: Sendable, Equatable {
    case pending
    case finished(PingResult)
}
