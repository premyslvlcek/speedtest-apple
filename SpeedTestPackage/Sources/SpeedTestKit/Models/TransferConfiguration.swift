//
//  TransferConfiguration.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// How the transfer service loads the line. Tuned on a device.
public struct TransferConfiguration: Sendable, Equatable {
    /// Parallel connections to the one server. The web client uses 6 to one server, 12 across four.
    public let connections = 4
    /// `?size=` for each `/download` request: 50 MB, what Ubiquiti's own web client starts with.
    public let downloadRequestBytes = 50_000_000
    /// One random buffer, allocated once and sent again and again with `POST /upload`.
    public let uploadBodyBytes = 8_000_000

    public init() {}
}
