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
    /// Without one (approximate mode): the first `approximateCount` in directory order, with no distances. More
    /// than `nearestCount`, because the directory's order isn't by distance, so latency picks from a wider set.
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
    /// measure; `failoverTarget(after:in:)` picks the one to try if it never starts.
    public static func order(_ candidates: [Candidate], minimumReplies: Int) -> [Candidate] {
        candidates.enumerated()
            .sorted { lhs, rhs in
                rankKey(lhs.element, offset: lhs.offset, minimumReplies: minimumReplies)
                    < rankKey(rhs.element, offset: rhs.offset, minimumReplies: minimumReplies)
            }
            .map(\.element)
    }

    /// The server to try when `failed` sends nothing: the next entry of `order` after it on another host, else
    /// the next entry. A second port of a host that just failed would most likely fail the same way.
    public static func failoverTarget(after failed: Candidate, in order: [Candidate]) -> Candidate? {
        guard let index = order.firstIndex(of: failed) else {
            return nil
        }
        let rest = order[(index + 1)...]
        return rest.first { $0.server.host != failed.server.host } ?? rest.first
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

    /// Tier, median, distance, input position. A missing median or distance counts as zero, so the next field
    /// decides.
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
