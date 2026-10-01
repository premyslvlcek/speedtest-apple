//
//  PingSessionTests.swift
//  ICMPTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
@testable import ICMP
import Testing

@Suite struct PingSessionTests {
    static let identifier: UInt16 = 0xBEEF
    static let token = Data("0123456789ABCDEF".utf8)

    /// The bytes of an ICMPv6 echo reply, as the remote host would send it back.
    static func reply(
        identifier: UInt16 = identifier,
        sequence: UInt16,
        payload: Data = token
    ) -> Data {
        EchoMessage(identifier: identifier, sequence: sequence, payload: payload).replyData(family: .ipv6)
    }

    static func makeSession(count: Int = 5) -> PingSession {
        PingSession(identifier: identifier, token: token, count: count, timeout: .seconds(1), family: .ipv6)
    }

    @Test func countsEveryMatchingReplyInArrivalOrder() {
        var session = Self.makeSession(count: 3)
        session.recordSent(sequence: 0, at: .milliseconds(0))
        session.recordSent(sequence: 1, at: .milliseconds(100))
        session.recordSent(sequence: 2, at: .milliseconds(200))

        session.record(datagram: Self.reply(sequence: 1), at: .milliseconds(105))
        session.record(datagram: Self.reply(sequence: 0), at: .milliseconds(130))
        #expect(!session.isComplete)
        session.record(datagram: Self.reply(sequence: 2), at: .milliseconds(207))

        #expect(session.isComplete)
        #expect(session.result == PingResult(
            rtts: [.milliseconds(5), .milliseconds(130), .milliseconds(7)],
            sent: 3
        ))
    }

    @Test func ignoresAReplyWithAnotherIdentifier() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.reply(identifier: 0x0001, sequence: 0), at: .milliseconds(5))

        #expect(session.result.received == 0)
    }

    @Test func ignoresAReplyWithAnotherToken() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.reply(sequence: 0, payload: Data("someone-else-xyz".utf8)), at: .milliseconds(5))

        #expect(session.result.received == 0)
    }

    @Test func ignoresASequenceThatWasNeverSent() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.reply(sequence: 7), at: .milliseconds(5))

        #expect(session.result.received == 0)
    }

    @Test func countsADuplicateReplyOnce() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.reply(sequence: 0), at: .milliseconds(5))
        session.record(datagram: Self.reply(sequence: 0), at: .milliseconds(6))

        #expect(session.result.rtts == [.milliseconds(5)])
    }

    @Test func ignoresAReplyThatCameAfterTheTimeout() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.reply(sequence: 0), at: .milliseconds(1001))

        #expect(session.result.received == 0)
    }

    @Test func countsAReplyThatCameExactlyAtTheTimeout() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.reply(sequence: 0), at: .seconds(1))

        #expect(session.result.rtts == [.seconds(1)])
    }

    @Test func ignoresAReplyTimestampedBeforeItsRequest() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .milliseconds(10))

        session.record(datagram: Self.reply(sequence: 0), at: .milliseconds(5))

        #expect(session.result.received == 0)
    }

    @Test func ignoresSomethingThatIsNotAnEchoReply() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .zero)

        let ownRequest = EchoMessage(identifier: Self.identifier, sequence: 0, payload: Self.token)
            .requestData(family: .ipv6)
        session.record(datagram: ownRequest, at: .milliseconds(1))

        #expect(session.result.received == 0)
    }

    @Test func sentIsTheCountWhenNothingWasSent() {
        #expect(Self.makeSession(count: 5).result == .noReply(sent: 5))
    }

    @Test func sentIsTheCountEvenWhenFewerWereRecorded() {
        // A request we meant to send and got no answer to is a loss: 1 of 5, not 1 of 2.
        var session = Self.makeSession(count: 5)
        session.recordSent(sequence: 0, at: .zero)
        session.recordSent(sequence: 1, at: .milliseconds(100))

        session.record(datagram: Self.reply(sequence: 0), at: .milliseconds(5))

        #expect(session.result == PingResult(rtts: [.milliseconds(5)], sent: 5))
    }

    @Test func countsAReplyWithAZeroRoundTrip() {
        var session = Self.makeSession()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.reply(sequence: 0), at: .zero)

        #expect(session.result.rtts == [.zero])
    }

    // MARK: - IPv4

    /// An IPv4 echo reply as the socket delivers it: a 20-byte IP header first, then the ICMP message.
    static func ipv4Reply(sequence: UInt16) -> Data {
        let header: [UInt8] = [0x45, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x01, 0x00, 0x00]
            + [0x7F, 0x00, 0x00, 0x01, 0x7F, 0x00, 0x00, 0x01]
        let message = EchoMessage(identifier: identifier, sequence: sequence, payload: token)
        return Data(header) + message.replyData(family: .ipv4)
    }

    static func makeIPv4Session() -> PingSession {
        PingSession(identifier: identifier, token: token, count: 5, timeout: .seconds(1), family: .ipv4)
    }

    @Test func anIPv4SessionCountsAnIPv4Reply() {
        var session = Self.makeIPv4Session()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.ipv4Reply(sequence: 0), at: .milliseconds(5))

        #expect(session.result.rtts == [.milliseconds(5)])
    }

    @Test func anIPv4SessionIgnoresAnIPv6Reply() {
        var session = Self.makeIPv4Session()
        session.recordSent(sequence: 0, at: .zero)

        session.record(datagram: Self.reply(sequence: 0), at: .milliseconds(5))

        #expect(session.result.received == 0)
    }
}
