//
//  TokenDTO.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The answer of `POST /api/v1/tokens`: `{"token": "<uuid>", "ttl": 80}`, with `ttl` in seconds.
struct TokenDTO: Decodable, Sendable {
    let token: String
    let ttl: Double
}

extension TokenDTO: DomainModelConvertible {
    func toDomainModel() -> TransferToken {
        TransferToken(dto: self)
    }
}

extension TransferToken {
    /// The token a directory answer carries.
    init(dto: TokenDTO) {
        self.init(value: dto.token, ttl: .seconds(dto.ttl))
    }
}
