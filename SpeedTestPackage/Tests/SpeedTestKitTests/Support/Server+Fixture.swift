//
//  Server+Fixture.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

@testable import SpeedTestKit

extension Server {
    /// A test server at `https://<name>.wifiman.me:<port>`, in Prague unless told otherwise.
    /// `provider` defaults to `name`, so tests can assert on order by reading `server.provider`.
    static func fixture(
        _ name: String,
        latitude: Double = 50.0755,
        longitude: Double = 14.4378,
        port: Int = 80,
        provider: String? = nil,
        city: String = "Prague"
    ) -> Server {
        let host = "\(name).wifiman.me"
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.port = port
        guard let url = components.url else {
            preconditionFailure("Invalid fixture server name: \(name)")
        }

        return Server(
            url: url,
            host: host,
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            provider: provider ?? name,
            city: city
        )
    }
}
