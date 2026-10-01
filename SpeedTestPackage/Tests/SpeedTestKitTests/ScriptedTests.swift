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
    @Test func theFixtureCandidatesAreTheFiveNearestWithOneHostOnTwoPorts() {
        let candidates = Fixtures.candidates

        #expect(candidates.count == 5)
        // Veselí is the farthest of the six and is left out.
        #expect(!candidates.map(\.server.city).contains("Veselí"))
        let elektro = candidates.filter { $0.server.provider == "Elektro Solution" && $0.server.city == "Prague" }
        #expect(elektro.map(\.server.port) == [81, 88])
        #expect(Set(elektro.map(\.server.host)).count == 1)
    }

    @Test func scriptedPingsAnswerByHost() async {
        let ping = withDependencies {
            $0.continuousClock = ImmediateClock()
        } operation: {
            PingService.scripted
        }
        let configuration = PingConfiguration.standard
        let elektro = Fixtures.candidates.filter { $0.server.provider == "Elektro Solution" }

        var results: [PingResult] = []
        for candidate in elektro {
            await results.append(ping.ping(candidate.server.host, configuration))
        }

        // The two Prague ports share one host and so one result; Zbožíčko never answers ICMP.
        let prague = elektro.filter { $0.server.city == "Prague" }.map(\.id)
        #expect(results.prefix(2).allSatisfy { $0 == Fixtures.pingResults[prague[0]] })
        #expect(results.last?.received == 0)
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
