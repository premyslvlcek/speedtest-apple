//
//  EngineFixtures.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ConcurrencyExtras
import SpeedTestKit

enum EngineFixtures {
    /// Wenceslas Square.
    static let prague = Coordinate(latitude: 50.0813, longitude: 14.4280)
    static let token = TransferToken(value: "token-1", ttl: .seconds(80))

    /// In directory order, which isn't by distance. The two `vinohrady` entries share a host.
    static let servers: [Server] = [
        .fixture("brno", latitude: 49.1951, longitude: 16.6068, city: "Brno"),
        .fixture("karlin", latitude: 50.0925, longitude: 14.4510),
        .fixture("vinohrady", latitude: 50.0755, longitude: 14.4378),
        .fixture("vinohrady", latitude: 50.0750, longitude: 14.4400, port: 88),
        .fixture("smichov", latitude: 50.0707, longitude: 14.4035),
        .fixture("kladno", latitude: 50.1473, longitude: 14.1029, city: "Kladno"),
        .fixture("benesov", latitude: 49.7817, longitude: 14.6868, city: "Benesov")
    ]
}

/// A directory that answers from memory and counts its calls.
final class StubDirectory: Sendable {
    private let servers: [Server]
    private let fetchError: (any Error)?
    private let tokenError: (any Error)?
    private let fetchLog = LockIsolated<[Coordinate?]>([])
    private let tokenLog = LockIsolated(0)

    init(
        servers: [Server] = EngineFixtures.servers,
        fetchError: (any Error)? = nil,
        tokenError: (any Error)? = nil
    ) {
        self.servers = servers
        self.fetchError = fetchError
        self.tokenError = tokenError
    }

    var fetchedNear: [Coordinate?] {
        fetchLog.value
    }

    var tokenCalls: Int {
        tokenLog.value
    }

    var directory: ServerDirectory {
        ServerDirectory(
            fetch: { near in
                self.fetchLog.withValue { $0.append(near) }
                if let fetchError = self.fetchError {
                    throw fetchError
                }
                return self.servers
            },
            token: {
                self.tokenLog.withValue { $0 += 1 }
                if let tokenError = self.tokenError {
                    throw tokenError
                }
                return EngineFixtures.token
            }
        )
    }
}
