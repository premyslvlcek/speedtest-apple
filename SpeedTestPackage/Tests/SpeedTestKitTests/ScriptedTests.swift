//
//  ScriptedTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Clocks
import Dependencies
import ICMP
import SpeedTestKit
import Testing
import TestSupport

/// The scripted collaborators that previews and the UI tests run on. On an `ImmediateClock` their delays pass at once.
@Suite(.mainSerialExecutor, .timeLimit(.minutes(1))) struct ScriptedTests {
    @Test func scriptedPingsAnswerByHost() async throws {
        let ping = withDependencies {
            $0.continuousClock = ImmediateClock()
        } operation: {
            PingService.scripted
        }
        let configuration = PingConfiguration.standard
        let ubiquiti = try #require(Fixtures.servers.first { $0.provider == "Ubiquiti" })
        let jablonka = try #require(Fixtures.servers.first { $0.provider == "jablonka.cz" })

        // Two hosts with different fixture results, so a lookup that ignored the host would fail.
        #expect(await ping.ping(ubiquiti.host, configuration) == Fixtures.pingResults[ubiquiti.id])
        #expect(await ping.ping(jablonka.host, configuration) == Fixtures.pingResults[jablonka.id])
        #expect(Fixtures.pingResults[ubiquiti.id] != Fixtures.pingResults[jablonka.id])
        #expect(await ping.ping("unknown.example.invalid", configuration) == .noReply(sent: configuration.count))
    }

    @Test(arguments: [(TransferDirection.download, Duration.seconds(15)), (.upload, .seconds(10))])
    func theScriptedMeterRampsUpAndEndsAtTheDuration(direction: TransferDirection, duration: Duration) async {
        let meter = withDependencies {
            $0.continuousClock = ImmediateClock()
        } operation: {
            TransferMeter.scripted
        }
        let server = Fixtures.servers[0]

        var samples: [ThroughputSample] = []
        do {
            for try await sample in meter.measure(server, direction, TransferToken(value: "token", ttl: .seconds(80))) {
                samples.append(sample)
            }
        } catch {
            Issue.record(error)
        }

        #expect(samples.last?.elapsed == duration)
        #expect(samples.first?.currentMbps ?? 0 < samples.last?.currentMbps ?? 0)
    }
}
