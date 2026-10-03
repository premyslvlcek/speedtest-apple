//
//  ServerDTO.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// One element of `GET /api/v2/servers`. Only the fields the app uses are decoded; the rest (country, speed,
/// `providerUrl`) are ignored, so a missing one doesn't cost a usable server.
struct ServerDTO: Decodable, Sendable {
    let url: String
    let latitude: Double
    let longitude: Double
    let provider: String
    let city: String
}

extension Server {
    /// The server a directory entry describes. `nil` for an entry the app can't use: not `https`, or not a host under
    /// `wifiman.me`. The app sends a test token and 25 s of traffic to the server it picks, so it only goes where
    /// Ubiquiti's test servers live, even if the directory ever names another host.
    init?(dto: ServerDTO) {
        guard let url = URL(string: dto.url), url.scheme?.lowercased() == "https", let host = url.host()?.lowercased(),
              host.hasSuffix(Self.testServerDomain)
        else {
            return nil
        }

        self.init(
            url: url,
            host: host,
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            provider: dto.provider,
            city: dto.city
        )
    }

    /// Every test server the directory lists is a subdomain of this.
    static let testServerDomain = ".wifiman.me"
}

extension ServerDTO {
    /// Decodes the list one element at a time, so a malformed entry is skipped instead of failing the list.
    /// Then drops entries the app can't use and repeated URLs.
    /// Throws only when the body isn't a JSON array at all.
    static func servers(from data: Data) throws -> [Server] {
        let elements = try JSONDecoder().decode([Lossy].self, from: data)
        var seen = Set<URL>()
        return elements
            .compactMap { $0.dto.flatMap(Server.init(dto:)) }
            .filter { seen.insert($0.url).inserted }
    }
}

/// Wraps one array element; a malformed one decodes as `nil` instead of throwing.
private struct Lossy: Decodable {
    let dto: ServerDTO?

    init(from decoder: any Decoder) throws {
        dto = try? ServerDTO(from: decoder)
    }
}
