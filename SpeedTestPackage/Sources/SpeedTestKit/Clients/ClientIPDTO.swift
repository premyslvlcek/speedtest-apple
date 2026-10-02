//
//  ClientIPDTO.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 02.10.2026.
//

/// The answer of `GET /api/v1/ip`. It also carries the country, an approximate coordinate and the time zone,
/// which the app doesn't use.
struct ClientIPDTO: Decodable, Sendable {
    let ip: String
    let isp: String?
}

extension ClientIPDTO: DomainModelConvertible {
    func toDomainModel() -> ClientIP {
        ClientIP(dto: self)
    }
}

extension ClientIP {
    /// The address a directory answer carries. An empty provider counts as unknown.
    init(dto: ClientIPDTO) {
        let provider = dto.isp.flatMap { $0.isEmpty ? nil : $0 }
        self.init(address: dto.ip, provider: provider)
    }
}
