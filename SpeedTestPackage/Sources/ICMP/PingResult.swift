//
//  PingResult.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// What came back from one `ping()` call.
public struct PingResult: Sendable, Equatable {
    /// Round-trip times of the replies, in the order they arrived.
    public var rtts: [Duration]
    public var sent: Int

    public init(rtts: [Duration], sent: Int) {
        self.rtts = rtts
        self.sent = sent
    }

    public var received: Int {
        rtts.count
    }

    /// The median round-trip time; for an even count, the mean of the middle two. `nil` with no replies.
    public var median: Duration? {
        guard !rtts.isEmpty else {
            return nil
        }

        let sorted = rtts.sorted()
        let middle = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

    public var isReachable: Bool {
        received > 0
    }

    public static func noReply(sent: Int) -> PingResult {
        PingResult(rtts: [], sent: sent)
    }
}
