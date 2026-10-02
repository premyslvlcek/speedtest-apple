//
//  ClientIP.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 02.10.2026.
//

/// The device's public address as the directory sees it, and the provider that owns it.
public struct ClientIP: Sendable, Equatable {
    public let address: String
    /// `nil` when the directory doesn't know the provider.
    public let provider: String?

    public init(address: String, provider: String?) {
        self.address = address
        self.provider = provider
    }
}
