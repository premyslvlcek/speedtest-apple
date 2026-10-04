//
//  Pinger.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// Sends ICMP echo requests to one host and measures the round-trip times.
///
/// Uses an unprivileged datagram socket (`SOCK_DGRAM` + `IPPROTO_ICMP`/`IPPROTO_ICMPV6`), so it needs no
/// root and works in an app. The socket is `connect()`ed, so the kernel delivers only this host's replies;
/// a random identifier and payload token per call keep another pinger's replies out as well.
///
/// A value with no mutable state: every call has its own socket, identifier and stream.
public struct Pinger: Sendable {
    fileprivate enum Event: Sendable {
        case sent(UInt16, time: Duration)
        case datagram(Data, time: Duration)
        case deadline
    }

    private let host: String
    private let clock: any Clock<Duration>
    private let resolve: @Sendable (String) async -> ResolvedAddress?
    private let openSocket: SocketOpener

    public init(host: String, clock: any Clock<Duration> = ContinuousClock()) {
        self.init(host: host, clock: clock, resolve: AddressResolver.resolve, openSocket: ICMPSocket.live)
    }

    init(
        host: String,
        clock: any Clock<Duration>,
        resolve: @escaping @Sendable (String) async -> ResolvedAddress?,
        openSocket: @escaping SocketOpener
    ) {
        self.host = host
        self.clock = clock
        self.resolve = resolve
        self.openSocket = openSocket
    }

    /// `@concurrent`: the work runs off the caller's actor, so pinging from the main actor never runs there.
    @concurrent
    public func ping(_ configuration: PingConfiguration = .standard) async -> PingResult {
        precondition(
            (1 ... Int(UInt16.max) + 1).contains(configuration.count),
            "A ping sends 1 to 65 536 requests: each one gets its own 16-bit sequence number."
        )
        let noReply = PingResult.noReply(sent: configuration.count)

        // A ping that was cancelled (Stop) before or while the address was looked up sends nothing.
        guard let address = await resolve(host), !Task.isCancelled else {
            return noReply
        }

        // Everything that happens during the call arrives through this one stream, in order: a `.sent`
        // is always yielded before its request goes out, and a datagram is yielded the moment it's read.
        // A fake socket that answers inside `send` therefore puts each reply right after its `.sent`, and
        // `.deadline` comes last. That ordering is what makes the tests deterministic with ImmediateClock.
        let (events, continuation) = AsyncStream.makeStream(of: Event.self)
        let stopwatch = Stopwatch(clock: clock)

        let socket: ICMPSocket
        do {
            socket = try openSocket(address) { datagram in
                continuation.yield(.datagram(datagram, time: stopwatch.elapsed()))
            }
        } catch {
            return noReply
        }

        defer {
            continuation.finish()
            socket.close()
        }

        let identifier = UInt16.random(in: .min ... .max)
        let token = Data((0 ..< Self.tokenLength).map { _ in UInt8.random(in: .min ... .max) })
        // A local copy, so the child task below captures only the clock.
        let clock = clock

        return await withTaskGroup(of: Void.self) { group in
            let sender = RequestSender(
                configuration: configuration,
                family: address.family,
                identifier: identifier,
                token: token
            )
            group.addTask {
                await sender.run(socket: socket, clock: clock, stopwatch: stopwatch, continuation: continuation)
            }

            var session = PingSession(
                identifier: identifier,
                token: token,
                count: configuration.count,
                timeout: configuration.timeout,
                family: address.family
            )

            await Self.collect(events, into: &session)
            group.cancelAll()
            return session.result
        }
    }

    /// The random payload that marks our replies: 16 bytes, so another pinger can't match it by chance.
    private static let tokenLength = 16

    /// Feeds events into the session until every request is answered or the deadline passes.
    private static func collect(_ events: AsyncStream<Event>, into session: inout PingSession) async {
        for await event in events {
            switch event {
            case let .sent(sequence, time):
                session.recordSent(sequence: sequence, at: time)

            case let .datagram(datagram, time):
                session.record(datagram: datagram, at: time)

            case .deadline:
                return
            }

            if session.isComplete {
                return
            }
        }
    }
}

/// Sends the requests `interval` apart, then waits `timeout` after the last one and yields `.deadline`.
/// A failed `send` still counts as sent: that request simply gets no reply.
private struct RequestSender: Sendable {
    let configuration: PingConfiguration
    let family: AddressFamily
    let identifier: UInt16
    let token: Data

    func run(
        socket: ICMPSocket,
        clock: any Clock<Duration>,
        stopwatch: Stopwatch,
        continuation: AsyncStream<Pinger.Event>.Continuation
    ) async {
        // However the sender ends (deadline or cancellation), the loop in `collect(_:into:)` must stop waiting.
        defer {
            continuation.finish()
        }

        for index in 0 ..< configuration.count {
            let sequence = UInt16(index)
            continuation.yield(.sent(sequence, time: stopwatch.elapsed()))
            let request = EchoMessage(identifier: identifier, sequence: sequence, payload: token)
            try? socket.send(request.requestData(family: family))

            if index < configuration.count - 1 {
                do {
                    try await clock.sleep(for: configuration.interval)
                } catch {
                    return
                }
            }
        }

        do {
            try await clock.sleep(for: configuration.timeout)
        } catch {
            return
        }

        continuation.yield(.deadline)
    }
}
