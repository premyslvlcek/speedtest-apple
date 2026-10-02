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
        private let clientIPResult: Result<ClientIP, any Error>

        init(
            servers: Result<[Server], any Error> = .success(Fixtures.servers),
            token: Result<TransferToken, any Error> = .success(RunFakes.token),
            clientIP: Result<ClientIP, any Error> = .success(Fixtures.clientIP)
        ) {
            self.servers = servers
            tokenResult = token
            clientIPResult = clientIP
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
                },
                clientIP: {
                    try self.clientIPResult.get()
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

    /// One measurement per `measure` call, in order, and a record of each call.
    final class Meter: Sendable {
        enum Measurement: Sendable {
            /// Yields the samples, then finishes, or fails with `error`.
            case samples([ThroughputSample], then: SpeedTestError? = nil)
            /// Yields the samples, then waits until the effect is cancelled (Stop).
            case samplesThenWait([ThroughputSample])
        }

        struct Start: Equatable {
            let server: Server.ID
            let direction: TransferDirection
            let token: String
        }

        let starts = LockIsolated<[Start]>([])
        private let measurements: LockIsolated<[Measurement]>
        /// Keeps the waiting streams open until their consumer goes away.
        private let open = LockIsolated<[AsyncThrowingStream<ThroughputSample, any Error>.Continuation]>([])

        init(_ measurements: [Measurement]) {
            self.measurements = LockIsolated(measurements)
        }

        var client: TransferMeter {
            TransferMeter(measure: { server, direction, token in
                self.starts.withValue {
                    $0.append(Start(server: server.id, direction: direction, token: token.value))
                }
                let measurement = self.measurements.withValue { $0.isEmpty ? .samples([]) : $0.removeFirst() }
                let (stream, continuation) = AsyncThrowingStream.makeStream(
                    of: ThroughputSample.self,
                    throwing: (any Error).self
                )
                switch measurement {
                case let .samples(samples, error):
                    samples.forEach { continuation.yield($0) }
                    continuation.finish(throwing: error)

                case let .samplesThenWait(samples):
                    samples.forEach { continuation.yield($0) }
                    self.open.withValue { $0.append(continuation) }
                }
                return stream
            })
        }
    }

    /// Short transfers: two download samples and one upload sample. 12.5 MB in 0.25 s is 400 Mbps.
    static let download1 = ThroughputSample(
        elapsed: .milliseconds(250), totalBytes: 12_500_000, currentMbps: 400, averageMbps: 400
    )
    static let download2 = ThroughputSample(
        elapsed: .milliseconds(500), totalBytes: 28_750_000, currentMbps: 520, averageMbps: 460
    )
    static let upload1 = ThroughputSample(
        elapsed: .milliseconds(250), totalBytes: 2_875_000, currentMbps: 92, averageMbps: 92
    )
}
