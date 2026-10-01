//
//  TransferToken.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The `x-test-token` for `/download` and `/upload`. A fresh one per run; it lives 80 s.
public struct TransferToken: Sendable, Equatable {
    public let value: String
    public let ttl: Duration

    public init(value: String, ttl: Duration) {
        self.value = value
        self.ttl = ttl
    }
}
