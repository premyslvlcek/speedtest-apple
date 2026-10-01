//
//  Scripted.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import ICMP

// Scripted dependency clients: together they play a whole run in about 5 s with no network, no location prompt and
// no ICMP. Xcode previews get them as the preview values; the UI tests switch them on at launch. Their delays
// run on the registered `continuousClock`, resolved when each value is created.

public extension Locator {
    /// Finds Prague after a short moment.
    static var scripted: Locator {
        @Dependency(\.continuousClock) var clock
        return Locator(locate: { _ in
            try? await clock.sleep(for: .milliseconds(400))
            return .located(Fixtures.prague)
        })
    }
}

public extension ServerDirectory {
    /// Lists the fixture servers and hands out a token.
    static var scripted: ServerDirectory {
        @Dependency(\.continuousClock) var clock
        return ServerDirectory(
            fetch: { _ in
                try await clock.sleep(for: .milliseconds(150))
                return Fixtures.servers
            },
            token: {
                TransferToken(value: "scripted", ttl: .seconds(80))
            }
        )
    }
}

public extension PingService {
    /// Answers with the fixture result for the host, each after its own delay, so results arrive one by one.
    static var scripted: PingService {
        @Dependency(\.continuousClock) var clock
        return PingService(ping: { host, configuration in
            let position = Fixtures.servers.firstIndex { $0.host == host } ?? 0
            try? await clock.sleep(for: .milliseconds(100) * (position + 1))
            return Fixtures.pingResult(forHost: host) ?? .noReply(sent: configuration.count)
        })
    }
}

public extension TransferMeter {
    /// A ramp at the real sample times (every 250 ms to 15 s or 10 s), played faster: download samples 50 ms apart
    /// (3 s on screen, long enough for a UI test to tap Stop mid-download), upload samples 25 ms apart.
    static var scripted: TransferMeter {
        @Dependency(\.continuousClock) var clock
        return TransferMeter(measure: { _, direction, _ in
            let (peakMbps, duration, step): (Double, Duration, Duration) = switch direction {
            case .download:
                (486, .seconds(15), .milliseconds(50))

            case .upload:
                (92, .seconds(10), .milliseconds(25))
            }
            let samples = Fixtures.samples(peakMbps: peakMbps, duration: duration, interval: .milliseconds(250))

            let (stream, continuation) = AsyncThrowingStream.makeStream(
                of: ThroughputSample.self,
                throwing: (any Error).self
            )
            let playback = Task { [clock, samples, step, continuation] in
                for sample in samples {
                    do {
                        try await clock.sleep(for: step)
                    } catch {
                        break
                    }
                    continuation.yield(sample)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                playback.cancel()
            }
            return stream
        })
    }
}
