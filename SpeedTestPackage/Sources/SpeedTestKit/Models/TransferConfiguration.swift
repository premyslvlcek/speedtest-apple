//
//  TransferConfiguration.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// How the transfer service loads the line. Tuned on a device.
public struct TransferConfiguration: Sendable, Equatable {
    /// Parallel connections to the one server. The web client uses 6.
    public var connections: Int
    /// `?size=` for each `/download` request: 50 MB, what Ubiquiti's own web client starts with.
    public var downloadRequestBytes: Int
    /// One random buffer, allocated once and sent again and again with `POST /upload`.
    public var uploadBodyBytes: Int

    public init(connections: Int = 4, downloadRequestBytes: Int = 50_000_000, uploadBodyBytes: Int = 8_000_000) {
        self.connections = connections
        self.downloadRequestBytes = downloadRequestBytes
        self.uploadBodyBytes = uploadBodyBytes
    }
}
