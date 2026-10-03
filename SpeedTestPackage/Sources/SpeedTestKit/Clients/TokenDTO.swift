//
//  TokenDTO.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The answer of `POST /api/v1/tokens`: `{"token": "<uuid>", "ttl": 80}`. Only the token is read; a run never
/// outlives its 80 s lifetime.
struct TokenDTO: Decodable, Sendable {
    let token: String
}

extension TransferToken {
    /// The token a directory answer carries.
    init(dto: TokenDTO) {
        self.init(value: dto.token)
    }
}
