//
//  EchoMessageTests.swift
//  ICMPTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
@testable import ICMP
import Testing

@Suite struct EchoMessageTests {
    /// Real bytes, captured on macOS 26.6 (2026-09-30) from unprivileged ICMP datagram sockets pinging
    /// 127.0.0.1 and ::1 with identifier 0x1234, sequence 1 and the payload "SpeedTestPayload".
    enum Captured {
        static let payload = Data("SpeedTestPayload".utf8)
        static let message = EchoMessage(identifier: 0x1234, sequence: 1, payload: payload)

        static let ipv4Request: [UInt8] = [
            0x08, 0x00, 0xBF, 0x8F, 0x12, 0x34, 0x00, 0x01,
            0x53, 0x70, 0x65, 0x65, 0x64, 0x54, 0x65, 0x73, 0x74, 0x50, 0x61, 0x79, 0x6C, 0x6F, 0x61, 0x64
        ]

        /// What `recv` returned: a 20-byte IPv4 header (note `ip_len` 0x1800 in host byte order), then
        /// the type-0 reply.
        static let ipv4ReplyWithHeader: [UInt8] = [
            0x45, 0x00, 0x18, 0x00, 0x0C, 0x53, 0x00, 0x00, 0x40, 0x01, 0x00, 0x00,
            0x7F, 0x00, 0x00, 0x01, 0x7F, 0x00, 0x00, 0x01,
            0x00, 0x00, 0xC7, 0x8F, 0x12, 0x34, 0x00, 0x01,
            0x53, 0x70, 0x65, 0x65, 0x64, 0x54, 0x65, 0x73, 0x74, 0x50, 0x61, 0x79, 0x6C, 0x6F, 0x61, 0x64
        ]

        /// On ::1 the socket first receives its own type-128 request, with the checksum the kernel filled in.
        static let ipv6OwnRequest: [UInt8] = [
            0x80, 0x00, 0x47, 0x3B, 0x12, 0x34, 0x00, 0x01,
            0x53, 0x70, 0x65, 0x65, 0x64, 0x54, 0x65, 0x73, 0x74, 0x50, 0x61, 0x79, 0x6C, 0x6F, 0x61, 0x64
        ]

        /// Then the type-129 reply, with no IPv6 header.
        static let ipv6Reply: [UInt8] = [
            0x81, 0x00, 0x46, 0x3B, 0x12, 0x34, 0x00, 0x01,
            0x53, 0x70, 0x65, 0x65, 0x64, 0x54, 0x65, 0x73, 0x74, 0x50, 0x61, 0x79, 0x6C, 0x6F, 0x61, 0x64
        ]
    }

    // MARK: - Checksum

    @Test func checksumMatchesTheRFC1071Example() {
        // RFC 1071, section 3: the words 0001 f203 f4f5 f6f7 sum to ddf2, so the checksum is 220d.
        let bytes = Data([0x00, 0x01, 0xF2, 0x03, 0xF4, 0xF5, 0xF6, 0xF7])

        #expect(EchoMessage.checksum(bytes) == 0x220D)
    }

    @Test func checksumPadsAnOddByteCountWithZero() {
        #expect(EchoMessage.checksum(Data([0x01])) == 0xFEFF)
    }

    @Test func checksumOfAPacketIncludingItsChecksumIsZero() {
        #expect(EchoMessage.checksum(Data(Captured.ipv4Request)) == 0)
    }

    // MARK: - Encoding

    @Test func ipv4RequestMatchesTheCapturedBytes() {
        let request = Captured.message.requestData(family: .ipv4)

        #expect([UInt8](request) == Captured.ipv4Request)
    }

    @Test func ipv6RequestLeavesTheChecksumToTheKernel() {
        let request = Captured.message.requestData(family: .ipv6)

        #expect([UInt8](request.prefix(8)) == [0x80, 0x00, 0x00, 0x00, 0x12, 0x34, 0x00, 0x01])
        #expect(request.dropFirst(8) == Captured.payload)
    }

    @Test func ipv4ReplyDataMatchesTheCapturedReplyWithoutItsIPHeader() {
        let reply = Captured.message.replyData(family: .ipv4)

        #expect([UInt8](reply) == Array(Captured.ipv4ReplyWithHeader.dropFirst(20)))
    }

    @Test func ipv6ReplyDataMatchesTheCapturedReplyApartFromTheKernelChecksum() {
        var expected = Captured.ipv6Reply
        expected[2] = 0
        expected[3] = 0

        #expect([UInt8](Captured.message.replyData(family: .ipv6)) == expected)
    }

    // MARK: - Decoding requests (for test fakes that play the remote host)

    @Test func anIPv4RequestIsParsed() {
        #expect(EchoMessage(requestData: Data(Captured.ipv4Request), family: .ipv4) == Captured.message)
    }

    @Test func anIPv6RequestIsParsed() {
        #expect(EchoMessage(requestData: Data(Captured.ipv6OwnRequest), family: .ipv6) == Captured.message)
    }

    @Test func aReplyIsNotARequest() {
        #expect(EchoMessage(requestData: Data(Captured.ipv6Reply), family: .ipv6) == nil)
    }

    // MARK: - Decoding replies

    @Test func ipv4ReplyIsParsedPastItsIPHeader() {
        #expect(EchoMessage(replyData: Data(Captured.ipv4ReplyWithHeader), family: .ipv4) == Captured.message)
    }

    @Test func ipv6ReplyIsParsed() {
        #expect(EchoMessage(replyData: Data(Captured.ipv6Reply), family: .ipv6) == Captured.message)
    }

    @Test func ourOwnIPv6RequestIsNotAReply() {
        #expect(EchoMessage(replyData: Data(Captured.ipv6OwnRequest), family: .ipv6) == nil)
    }

    @Test func anIPv4RequestIsNotAReply() {
        var withHeader = Array(Captured.ipv4ReplyWithHeader.prefix(20))
        withHeader.append(contentsOf: Captured.ipv4Request)

        #expect(EchoMessage(replyData: Data(withHeader), family: .ipv4) == nil)
    }

    @Test func anIPv4ReplyWithoutItsHeaderIsRejected() {
        let bare = Data(Captured.ipv4ReplyWithHeader.dropFirst(20))

        #expect(EchoMessage(replyData: bare, family: .ipv4) == nil)
    }

    @Test func truncatedDataIsRejected() {
        #expect(EchoMessage(replyData: Data(Captured.ipv6Reply.prefix(7)), family: .ipv6) == nil)
        #expect(EchoMessage(replyData: Data(Captured.ipv4ReplyWithHeader.prefix(27)), family: .ipv4) == nil)
        #expect(EchoMessage(replyData: Data(), family: .ipv4) == nil)
    }

    @Test func anEmptyPayloadIsAccepted() {
        let reply = EchoMessage(replyData: Data(Captured.ipv6Reply.prefix(8)), family: .ipv6)

        #expect(reply == EchoMessage(identifier: 0x1234, sequence: 1, payload: Data()))
    }

    @Test func aReplyWithANonZeroCodeIsRejected() {
        var reply = Captured.ipv6Reply
        reply[1] = 1

        #expect(EchoMessage(replyData: Data(reply), family: .ipv6) == nil)
    }

    @Test func anIPv4HeaderWithOptionsIsSkippedByItsLength() {
        // 0x46: a 6-word, 24-byte header, i.e. the 20 bytes above plus 4 bytes of options (NOPs).
        var withOptions = Array(Captured.ipv4ReplyWithHeader.prefix(20))
        withOptions[0] = 0x46
        withOptions.append(contentsOf: [0x01, 0x01, 0x01, 0x01])
        withOptions.append(contentsOf: Captured.ipv4ReplyWithHeader.dropFirst(20))

        #expect(EchoMessage(replyData: Data(withOptions), family: .ipv4) == Captured.message)
    }

    @Test func anIPv4HeaderShorterThanTheMinimumIsRejected() {
        // 0x44 claims a 4-word, 16-byte header, which IPv4 doesn't allow. A valid reply follows those
        // 16 bytes, so only the minimum-length check can reject it.
        var shortHeader = Array(Captured.ipv4ReplyWithHeader.prefix(16))
        shortHeader[0] = 0x44
        shortHeader.append(contentsOf: Captured.ipv4ReplyWithHeader.dropFirst(20))

        #expect(EchoMessage(replyData: Data(shortHeader), family: .ipv4) == nil)
    }
}
