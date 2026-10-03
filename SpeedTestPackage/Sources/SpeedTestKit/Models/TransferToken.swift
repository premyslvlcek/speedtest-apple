//
//  TransferToken.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The `x-test-token` for `/download` and `/upload`. A fresh one per run: it lives 80 s and a run takes at most
/// about 40 s, so the app never needs to know when it expires.
public struct TransferToken: Sendable, Equatable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}
