//
//  ServerDTO.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// One element of `GET /api/v2/servers`. `providerUrl` is ignored. Fields the app doesn't show are
/// optional, so a missing one doesn't cost a usable server.
struct ServerDTO: Decodable, Sendable {
    let url: String
    let latitude: Double
    let longitude: Double
    let provider: String
    let city: String
    let country: String?
    let countryCode: String?
    let speedMbps: Int?
}

extension ServerDTO: DomainModelConvertible {
    /// The server this entry describes, or `nil` when the app can't use it.
    func toDomainModel() -> Server? {
        Server(dto: self)
    }
}

extension Server {
    /// The server a directory entry describes. `nil` for an entry the app can't use: not `https`, or no host.
    init?(dto: ServerDTO) {
        guard let url = URL(string: dto.url), url.scheme?.lowercased() == "https", let host = url.host(),
              !host.isEmpty
        else {
            return nil
        }

        self.init(
            url: url,
            host: host,
            port: url.port ?? Self.httpsDefaultPort,
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            provider: dto.provider,
            city: dto.city,
            country: dto.country ?? "",
            countryCode: dto.countryCode ?? "",
            speedMbps: dto.speedMbps ?? 0
        )
    }

    /// The port an `https` URL means when it doesn't name one.
    private static let httpsDefaultPort = 443
}

extension ServerDTO {
    /// Decodes the list one element at a time, so a malformed entry is skipped instead of failing the list.
    /// Then drops entries the app can't use and repeated URLs.
    /// Throws only when the body isn't a JSON array at all.
    static func servers(from data: Data) throws -> [Server] {
        let elements = try JSONDecoder().decode([Lossy].self, from: data)
        var seen = Set<URL>()
        return elements
            .compactMap { $0.dto?.toDomainModel() }
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
