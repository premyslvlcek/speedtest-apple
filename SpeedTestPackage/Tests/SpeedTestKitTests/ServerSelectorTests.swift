//
//  ServerSelectorTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ICMP
import Testing

@testable import SpeedTestKit

@Suite struct ServerSelectorTests {
    static let prague = Coordinate(latitude: 50.0755, longitude: 14.4378)

    // MARK: Candidates

    @Test func picksTheFiveNearestByDistanceNotByDirectoryOrder() {
        // The directory's order isn't by distance when it locates us by IP. 0.01° of latitude ≈ 1.1 km.
        let servers = [
            Server.fixture("far", latitude: 51.0755),
            Server.fixture("d3", latitude: 50.1055),
            Server.fixture("d1", latitude: 50.0855),
            Server.fixture("d6", latitude: 50.1355),
            Server.fixture("d2", latitude: 50.0955),
            Server.fixture("d4", latitude: 50.1155),
            Server.fixture("d5", latitude: 50.1255)
        ]

        let candidates = ServerSelector.candidates(
            from: servers,
            location: Self.prague,
            nearestCount: 5,
            approximateCount: 10
        )

        #expect(candidates.map(\.server.provider) == ["d1", "d2", "d3", "d4", "d5"])
    }

    @Test func equalDistancesKeepDirectoryOrder() {
        // Two real servers share one coordinate (jablonka.cz and Cznet.cz in Prague).
        let servers = [
            Server.fixture("first", latitude: 50.08, longitude: 14.42),
            Server.fixture("second", latitude: 50.08, longitude: 14.42),
            Server.fixture("nearer", latitude: 50.0756)
        ]

        let candidates = ServerSelector.candidates(
            from: servers,
            location: Self.prague,
            nearestCount: 5,
            approximateCount: 10
        )

        #expect(candidates.map(\.server.provider) == ["nearer", "first", "second"])
    }

    @Test func theNearestCountIsConfigurable() {
        let servers = (1 ... 4).map { Server.fixture("s\($0)", latitude: 50.0755 + Double($0) / 100) }

        let candidates = ServerSelector.candidates(
            from: servers,
            location: Self.prague,
            nearestCount: 2,
            approximateCount: 10
        )

        #expect(candidates.map(\.server.provider) == ["s1", "s2"])
    }

    @Test func approximateModeTakesTheFirstTenInDirectoryOrderWithoutDistances() {
        let servers = (1 ... 12).map { Server.fixture("s\($0)", latitude: 50 + Double(13 - $0) / 10) }

        let candidates = ServerSelector.candidates(from: servers, location: nil, nearestCount: 5, approximateCount: 10)

        #expect(candidates.map(\.server.provider) == (1 ... 10).map { "s\($0)" })
        #expect(candidates.allSatisfy { $0.distance == nil })
    }

    // MARK: Order

    @Test func threeRepliesBeatALowerMedianWithFewerReplies() {
        let steady = Candidate(server: .fixture("steady"), distance: 2000, ping: replies([10, 11, 10, 12, 10]))
        let lossy = Candidate(server: .fixture("lossy"), distance: 1000, ping: replies([4, 5]))

        #expect(ServerSelector.order([lossy, steady], minimumReplies: 3).map(\.server.provider) == ["steady", "lossy"])
    }

    @Test func withinATierTheLowestMedianWins() {
        let slow = Candidate(server: .fixture("slow"), distance: 1000, ping: replies([8, 8, 8, 8, 8]))
        let fast = Candidate(server: .fixture("fast"), distance: 3000, ping: replies([5, 6, 5, 7, 5]))
        let justEnough = Candidate(server: .fixture("justEnough"), distance: 500, ping: replies([9, 9, 9]))

        let order = ServerSelector.order([slow, justEnough, fast], minimumReplies: 3)

        #expect(order.map(\.server.provider) == ["fast", "slow", "justEnough"])
    }

    @Test func withoutThreeRepliesAnywhereOneOrTwoRepliesStillRank() {
        let two = Candidate(server: .fixture("two"), distance: 1000, ping: replies([8, 9]))
        let one = Candidate(server: .fixture("one"), distance: 2000, ping: replies([5]))
        let silent = Candidate(server: .fixture("silent"), distance: 500, ping: noReply)

        let order = ServerSelector.order([silent, two, one], minimumReplies: 3)

        #expect(order.map(\.server.provider) == ["one", "two", "silent"])
    }

    @Test func noRepliesAtAllPutTheNearestFirst() {
        // The ICMP-blocked fallback: the engine reports it as .icmpBlocked.
        let far = Candidate(server: .fixture("far"), distance: 3000, ping: noReply)
        let near = Candidate(server: .fixture("near"), distance: 1000, ping: noReply)
        let middle = Candidate(server: .fixture("middle"), distance: 2000, ping: noReply)

        #expect(ServerSelector.order([far, near, middle], minimumReplies: 3).map(\.server.provider) == [
            "near",
            "middle",
            "far"
        ])
    }

    @Test func noRepliesInApproximateModeKeepDirectoryOrder() {
        let first = Candidate(server: .fixture("first"), distance: nil, ping: noReply)
        let second = Candidate(server: .fixture("second"), distance: nil, ping: noReply)
        let third = Candidate(server: .fixture("third"), distance: nil, ping: noReply)

        #expect(ServerSelector.order([first, second, third], minimumReplies: 3).map(\.server.provider) == [
            "first",
            "second",
            "third"
        ])
    }

    @Test func equalMediansGoToTheCloserServer() {
        let farther = Candidate(server: .fixture("farther"), distance: 2000, ping: replies([6, 6, 6, 6, 6]))
        let closer = Candidate(server: .fixture("closer"), distance: 1000, ping: replies([6, 6, 6, 6, 6]))

        #expect(ServerSelector.order([farther, closer], minimumReplies: 3).map(\.server.provider) == [
            "closer",
            "farther"
        ])
    }

    @Test func aPendingPingCountsAsNoReply() {
        let pending = Candidate(server: .fixture("pending"), distance: 500)
        let replied = Candidate(server: .fixture("replied"), distance: 2000, ping: replies([9, 9, 9, 9, 9]))

        #expect(ServerSelector.order([pending, replied], minimumReplies: 3).map(\.server.provider) == [
            "replied",
            "pending"
        ])
    }

    @Test func theSecondEntryIsTheFailoverTarget() {
        // Failover goes to the next one in the ranking, then the nearest of the rest.
        let best = Candidate(server: .fixture("best"), distance: 3000, ping: replies([4, 4, 4, 4, 4]))
        let next = Candidate(server: .fixture("next"), distance: 4000, ping: replies([7, 7, 7, 7, 7]))
        let lossy = Candidate(server: .fixture("lossy"), distance: 2000, ping: replies([3]))
        let silentNear = Candidate(server: .fixture("silentNear"), distance: 100, ping: noReply)
        let silentFar = Candidate(server: .fixture("silentFar"), distance: 5000, ping: noReply)

        let order = ServerSelector.order([silentFar, lossy, silentNear, next, best], minimumReplies: 3)

        #expect(order.map(\.server.provider) == ["best", "next", "lossy", "silentNear", "silentFar"])
    }

    @Test func theReplyThresholdIsConfigurable() {
        let two = Candidate(server: .fixture("two"), distance: 1000, ping: replies([8, 8]))
        let five = Candidate(server: .fixture("five"), distance: 1000, ping: replies([9, 9, 9, 9, 9]))

        #expect(ServerSelector.order([five, two], minimumReplies: 2).map(\.server.provider) == ["two", "five"])
    }
}

@Suite struct FailoverTargetTests {
    let first = Candidate(server: .fixture("vinohrady", port: 80), distance: 900)
    let otherPort = Candidate(server: .fixture("vinohrady", port: 88), distance: 1100)
    let otherHost = Candidate(server: .fixture("karlin"), distance: 2000)

    @Test func prefersTheNextEntryOnAnotherHost() {
        let target = ServerSelector.failoverTarget(after: first, in: [first, otherPort, otherHost])

        #expect(target == otherHost)
    }

    @Test func takesAnotherPortOfTheSameHostWhenNothingElseIsLeft() {
        let target = ServerSelector.failoverTarget(after: first, in: [first, otherPort])

        #expect(target == otherPort)
    }

    @Test func hasNoTargetAfterTheLastEntry() {
        #expect(ServerSelector.failoverTarget(after: first, in: [first]) == nil)
        // Only what comes after the failed server counts: the order is best first.
        #expect(ServerSelector.failoverTarget(after: first, in: [otherHost, first]) == nil)
    }
}

/// A finished ping with these round-trip times, out of `sent` requests.
private func replies(_ milliseconds: [Int], sent: Int = 5) -> PingState {
    .finished(PingResult(rtts: milliseconds.map { .milliseconds($0) }, sent: sent))
}

private let noReply = PingState.finished(.noReply(sent: 5))
