//
//  Fixtures.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import ICMP

/// Sample data for previews, the scripted clients and tests. The hosts are fake (`.example.invalid`); the providers
/// and cities are ones the directory lists near Prague, and the ping pattern mirrors what was measured there:
/// one server never answers ICMP, and one host is listed twice on different ports.
public enum Fixtures {
    public static let prague = Coordinate(latitude: 50.0755, longitude: 14.4378)

    /// An address from the documentation range (RFC 5737), never a real device's.
    public static let clientIP = ClientIP(address: "203.0.113.7", provider: "Example Networks")

    /// In the directory's order, which is not by distance.
    public static let servers: [Server] = [
        skylanVeseli,
        ubiquitiPrague,
        jablonkaPrague,
        elektroPrague81,
        elektroPrague88,
        elektroZbozicko
    ]

    /// The 5 nearest to `prague`, chosen by the real selection rules, ping pending.
    public static let candidates = ServerSelector.candidates(
        from: servers,
        location: prague,
        nearestCount: SpeedTestConfiguration.standard.nearestCount,
        approximateCount: SpeedTestConfiguration.standard.approximateCount
    )

    public static let pingResults: [Server.ID: PingResult] = [
        ubiquitiPrague.id: PingResult(rtts: milliseconds(6.4, 5.9, 6.1, 6.3, 6.0), sent: 5),
        jablonkaPrague.id: PingResult(rtts: milliseconds(5.8, 6.2, 5.9), sent: 5),
        elektroPrague81.id: sharedHostResult,
        elektroPrague88.id: sharedHostResult,
        elektroZbozicko.id: .noReply(sent: 5)
    ]

    /// A TCP-slow-start-like ramp that levels off at `peakMbps`, with a small repeatable wobble.
    /// One sample per `interval`, the last one exactly at `duration`.
    public static func samples(peakMbps: Double, duration: Duration, interval: Duration) -> [ThroughputSample] {
        let count = max(Int((duration.inSeconds / interval.inSeconds).rounded()), 1)
        var totalBytes: Int64 = 0

        return (1 ... count).map { index in
            let elapsed = interval * index
            let seconds = elapsed.inSeconds
            let current = peakMbps * (1 - exp(-seconds / 1.2)) * (1 + 0.04 * sin(seconds * 3.1))
            totalBytes += Int64(current * 1_000_000 / 8 * interval.inSeconds)
            return ThroughputSample(
                elapsed: elapsed,
                totalBytes: totalBytes,
                currentMbps: current,
                averageMbps: Double(totalBytes) * 8 / 1_000_000 / seconds
            )
        }
    }

    /// The ping result for a host: one entry per host, as the real pings are per host.
    public static func pingResult(forHost host: String) -> PingResult? {
        servers.first { $0.host == host }.flatMap { pingResults[$0.id] }
    }
}

private extension Fixtures {
    static let skylanVeseli = server(
        "skylan-veseli.example.invalid", port: 80, latitude: 49.1843, longitude: 14.6973,
        provider: "SKYLAN", city: "Veselí"
    )
    static let ubiquitiPrague = server(
        "ubiquiti-prague.example.invalid", port: 80, latitude: 50.0802, longitude: 14.4652,
        provider: "Ubiquiti", city: "Prague"
    )
    static let jablonkaPrague = server(
        "jablonka-prague.example.invalid", port: 80, latitude: 50.0839, longitude: 14.4287,
        provider: "jablonka.cz", city: "Prague"
    )
    static let elektroPrague81 = server(
        "elektro-solution.example.invalid", port: 81, latitude: 50.0710, longitude: 14.4580,
        provider: "Elektro Solution", city: "Prague"
    )
    static let elektroPrague88 = server(
        "elektro-solution.example.invalid", port: 88, latitude: 50.0710, longitude: 14.4580,
        provider: "Elektro Solution", city: "Prague"
    )
    static let elektroZbozicko = server(
        "elektro-zbozicko.example.invalid", port: 80, latitude: 50.2073, longitude: 15.2977,
        provider: "Elektro Solution", city: "Zbožíčko"
    )

    /// Ports 81 and 88 are one host, pinged once, so they share one result.
    static let sharedHostResult = PingResult(rtts: milliseconds(5.2, 5.0, 5.4, 5.1, 5.3), sent: 5)

    static func milliseconds(_ values: Double...) -> [Duration] {
        values.map { .microseconds(Int64(($0 * 1000).rounded())) }
    }

    static func server(
        _ host: String,
        port: Int,
        latitude: Double,
        longitude: Double,
        provider: String,
        city: String
    ) -> Server {
        guard let url = URL(string: "https://\(host):\(port)") else {
            preconditionFailure("Invalid fixture host \(host)")
        }

        return Server(
            url: url,
            host: host,
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            provider: provider,
            city: city
        )
    }
}
