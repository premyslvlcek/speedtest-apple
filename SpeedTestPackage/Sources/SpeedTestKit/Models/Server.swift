//
//  Server.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// One test server from the directory.
public struct Server: Sendable, Hashable, Identifiable {
    /// `https://<name>.wifiman.me:<port>`. Unique per entry; the same host can appear on two ports.
    public let url: URL
    public let host: String
    public let port: Int
    public let coordinate: Coordinate
    public let provider: String
    public let city: String
    public let country: String
    public let countryCode: String
    public let speedMbps: Int

    public var id: URL {
        url
    }

    /// The directory has no name field, so the app shows "provider · city".
    public var name: String {
        "\(provider) · \(city)"
    }

    public init(
        url: URL,
        host: String,
        port: Int,
        coordinate: Coordinate,
        provider: String,
        city: String,
        country: String,
        countryCode: String,
        speedMbps: Int
    ) {
        self.url = url
        self.host = host
        self.port = port
        self.coordinate = coordinate
        self.provider = provider
        self.city = city
        self.country = country
        self.countryCode = countryCode
        self.speedMbps = speedMbps
    }
}
