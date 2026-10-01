//
//  PingerTests.swift
//  ICMPTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Clocks
import Foundation
@testable import ICMP
import os
import Testing

@Suite(.timeLimit(.minutes(1))) struct PingerTests {
    static let address = ResolvedAddress(family: .ipv6, sockaddr: Data())

    /// A socket that answers inside `send`, like a network with zero latency. `answer` decides per request
    /// whether a reply comes back and can tamper with it.
    final class FakeSocket: Sendable {
        let isOpened = OSAllocatedUnfairLock(initialState: false)
        let sent = OSAllocatedUnfairLock<[UInt16]>(initialState: [])
        let isClosed = OSAllocatedUnfairLock(initialState: false)
        /// Each sequence number as its request goes out, so a test can wait for a send instead of polling.
        let sends: AsyncStream<UInt16>
        private let sendsContinuation: AsyncStream<UInt16>.Continuation
        let answer: @Sendable (EchoMessage) -> EchoMessage?

        init(answer: @escaping @Sendable (EchoMessage) -> EchoMessage? = { $0 }) {
            (sends, sendsContinuation) = AsyncStream.makeStream()
            self.answer = answer
        }

        var opener: SocketOpener {
            { [self] _, onDatagram in
                isOpened.withLock { $0 = true }
                return ICMPSocket(
                    send: { data in
                        guard let request = EchoMessage(requestData: data, family: .ipv6) else {
                            return
                        }

                        self.sent.withLock { $0.append(request.sequence) }
                        self.sendsContinuation.yield(request.sequence)

                        guard let reply = self.answer(request) else {
                            return
                        }

                        onDatagram(reply.replyData(family: .ipv6))
                    },
                    close: {
                        self.isClosed.withLock { $0 = true }
                    }
                )
            }
        }
    }

    static func makePinger(socket: FakeSocket, resolves: Bool = true) -> Pinger {
        Pinger(
            host: "example.test",
            clock: ImmediateClock(),
            resolve: { _ in resolves ? address : nil },
            openSocket: socket.opener
        )
    }

    @Test func countsAReplyToEveryRequest() async {
        let socket = FakeSocket()

        let result = await Self.makePinger(socket: socket).ping(.standard)

        #expect(result.received == 5)
        #expect(socket.sent.withLock { $0 } == [0, 1, 2, 3, 4])
        #expect(socket.isClosed.withLock { $0 })
    }

    @Test func noRepliesEndAtTheDeadlineAsNoReply() async {
        let socket = FakeSocket { _ in nil }

        let result = await Self.makePinger(socket: socket).ping(.standard)

        #expect(result == .noReply(sent: 5))
        #expect(socket.isClosed.withLock { $0 })
    }

    @Test func aHostThatDoesNotResolveIsNoReply() async {
        let socket = FakeSocket()

        let result = await Self.makePinger(socket: socket, resolves: false).ping(.standard)

        #expect(result == .noReply(sent: 5))
    }

    @Test func aSocketThatCannotOpenIsNoReply() async {
        struct NoRoute: Error {}
        let pinger = Pinger(
            host: "example.test",
            clock: ImmediateClock(),
            resolve: { _ in Self.address },
            openSocket: { _, _ in throw NoRoute() }
        )

        let result = await pinger.ping(.standard)

        #expect(result == .noReply(sent: 5))
    }

    @Test func anAnsweredPingReturnsWithoutWaitingForTheTimeout() async {
        // One request, answered inside `send`, so there's no interval to wait for. The clock never moves, so
        // the timeout after the request can never pass: `ping()` returns only because every request was
        // answered and it stopped the sender. Without that, it would wait forever (until the time limit).
        let socket = FakeSocket()
        let pinger = Pinger(
            host: "example.test",
            clock: TestClock(),
            resolve: { _ in Self.address },
            openSocket: socket.opener
        )

        let result = await pinger.ping(PingConfiguration(count: 1))

        #expect(result == PingResult(rtts: [.zero], sent: 1))
    }

    // MARK: - Cancellation (Stop)

    @Test func aPingCancelledBeforeItStartsSendsNothing() async {
        let socket = FakeSocket()
        let pinger = Self.makePinger(socket: socket)

        let ping = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await pinger.ping(.standard)
        }
        let result = await ping.value

        #expect(result == .noReply(sent: 5))
        #expect(!socket.isOpened.withLock { $0 })
    }

    @Test func cancellingAPingInFlightStopsSendingAndClosesTheSocket() async {
        // The clock never moves, so after the first request the sender waits for the interval until the
        // ping is cancelled. Without working cancellation this test would hang until the time limit.
        let socket = FakeSocket { _ in nil }
        let pinger = Pinger(
            host: "example.test",
            clock: TestClock(),
            resolve: { _ in Self.address },
            openSocket: socket.opener
        )

        let ping = Task { await pinger.ping(.standard) }
        var sends = socket.sends.makeAsyncIterator()
        _ = await sends.next()
        ping.cancel()
        let result = await ping.value

        #expect(result == .noReply(sent: 5))
        #expect(socket.sent.withLock { $0 } == [0])
        #expect(socket.isClosed.withLock { $0 })
    }
}
