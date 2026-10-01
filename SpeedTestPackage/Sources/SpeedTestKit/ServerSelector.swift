//
//  ServerSelector.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ICMP

/// Which servers to ping, and in what order to try them.
public enum ServerSelector {
    /// With a location: the `nearestCount` closest by great-circle distance, ties in directory order.
    /// Without one (approximate mode): the first `approximateCount` in directory order, with no distances,
    /// because latency decides and the directory's order isn't by distance.
    public static func candidates(
        from servers: [Server],
        location: Coordinate?,
        nearestCount: Int,
        approximateCount: Int
    ) -> [Candidate] {
        guard let location else {
            return servers.prefix(approximateCount).map { Candidate(server: $0, distance: nil) }
        }

        return servers.enumerated()
            .map { offset, server in
                (offset: offset, distance: server.coordinate.distance(to: location), server: server)
            }
            .sorted { ($0.distance, $0.offset) < ($1.distance, $1.offset) }
            .prefix(nearestCount)
            .map { Candidate(server: $0.server, distance: $0.distance) }
    }

    /// The full fallback order:
    /// 1. servers with at least `minimumReplies` replies, by lowest median
    /// 2. servers with fewer, but at least one, by lowest median
    /// 3. servers with no reply (or still pending), nearest first; in approximate mode, directory order
    ///
    /// Ties go to the closer server, else the earlier one in the input. The first entry is the server to
    /// measure; the second is the failover target.
    public static func order(_ candidates: [Candidate], minimumReplies: Int) -> [Candidate] {
        candidates.enumerated()
            .sorted { lhs, rhs in
                rankKey(lhs.element, offset: lhs.offset, minimumReplies: minimumReplies)
                    < rankKey(rhs.element, offset: rhs.offset, minimumReplies: minimumReplies)
            }
            .map(\.element)
    }

    /// How much a candidate's ping can be trusted, best first. Cases compare in declaration order.
    private enum Tier: Comparable {
        case enoughReplies
        case someReplies
        case noReply

        init(received: Int, minimumReplies: Int) {
            if received >= minimumReplies {
                self = .enoughReplies
            } else if received > 0 {
                self = .someReplies
            } else {
                self = .noReply
            }
        }
    }

    /// Compared field by field, which is exactly what tuple comparison does: tier, median, distance, input
    /// position. A missing median or distance counts as equal (zero), so the next field decides.
    private static func rankKey(
        _ candidate: Candidate,
        offset: Int,
        minimumReplies: Int
    ) -> (Tier, Duration, Double, Int) {
        let result = candidate.pingResult
        let tier = Tier(received: result?.received ?? 0, minimumReplies: minimumReplies)
        return (tier, result?.median ?? .zero, candidate.distance ?? 0, offset)
    }
}

private extension Candidate {
    /// The ping result, once it has arrived.
    var pingResult: PingResult? {
        switch ping {
        case let .finished(result):
            result

        case .pending:
            nil
        }
    }
}
