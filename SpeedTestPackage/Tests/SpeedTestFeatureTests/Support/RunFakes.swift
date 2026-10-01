//
//  RunFakes.swift
//  SpeedTestFeatureTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Clocks
import ConcurrencyExtras
import Foundation
import ICMP
import SpeedTestKit

/// Dependency clients for a run, built per test. Each answers at once, so with `TestStore`'s serial executor
/// the actions arrive in a fixed order: one `pinged` per distinct host, in candidate order.
enum RunFakes {
    static let token = TransferToken(value: "token-1", ttl: .seconds(80))

    static func locator(_ outcome: LocationOutcome = .located(Fixtures.prague)) -> Locator {
        Locator(locate: { _ in outcome })
    }

    /// Records what each request asked for.
    final class Directory: Sendable {
        let fetchedNear = LockIsolated<[Coordinate?]>([])
        let tokenCalls = LockIsolated(0)
        private let servers: Result<[Server], any Error>
        private let tokenResult: Result<TransferToken, any Error>

        init(
            servers: Result<[Server], any Error> = .success(Fixtures.servers),
            token: Result<TransferToken, any Error> = .success(RunFakes.token)
        ) {
            self.servers = servers
            tokenResult = token
        }

        var client: ServerDirectory {
            ServerDirectory(
                fetch: { near in
                    self.fetchedNear.withValue { $0.append(near) }
                    return try self.servers.get()
                },
                token: {
                    self.tokenCalls.withValue { $0 += 1 }
                    return try self.tokenResult.get()
                }
            )
        }
    }

    /// Answers with the fixture result for each host and records the hosts it was asked about.
    final class Pings: Sendable {
        let hosts = LockIsolated<[String]>([])
        private let result: @Sendable (String) -> PingResult

        init(result: @escaping @Sendable (String) -> PingResult = { Fixtures.pingResult(forHost: $0) ?? .noReply(sent: 5) }) {
            self.result = result
        }

        var client: PingService {
            PingService(ping: { host, _ in
                self.hosts.withValue { $0.append(host) }
                return self.result(host)
            })
        }
    }

    /// A ping that never answers until its effect is cancelled (Stop while pinging): it sleeps on a clock that
    /// never moves.
    static let pingUntilCancelled = PingService(ping: { _, configuration in
        try? await TestClock().sleep(for: .seconds(1))
        return .noReply(sent: configuration.count)
    })
}
