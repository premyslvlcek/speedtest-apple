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
    public let coordinate: Coordinate
    public let provider: String
    public let city: String

    public var id: URL {
        url
    }

    /// The directory has no name field, so the app shows "provider · city". The space before "·" doesn't break, so
    /// a wrapped name never starts a line with the separator.
    public var name: String {
        "\(provider)\u{00A0}· \(city)"
    }

    public init(
        url: URL,
        host: String,
        coordinate: Coordinate,
        provider: String,
        city: String
    ) {
        self.url = url
        self.host = host
        self.coordinate = coordinate
        self.provider = provider
        self.city = city
    }
}
