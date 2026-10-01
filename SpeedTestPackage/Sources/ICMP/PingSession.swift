//
//  PingSession.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// The bookkeeping of one `ping()` call: which requests went out when, and which datagrams count as
/// their replies. Pure, so the matching rules are tested without sockets or clocks.
struct PingSession {
    /// One echo request: when it went out, and its round-trip time once its reply has been counted.
    private struct Request {
        let sentAt: Duration
        var rtt: Duration?
    }

    private let identifier: UInt16
    private let token: Data
    private let count: Int
    private let timeout: Duration
    private let family: AddressFamily

    private var requests: [UInt16: Request] = [:]
    /// The counted round-trip times in arrival order, which is the order `PingResult` reports them in.
    private var rtts: [Duration] = []

    init(identifier: UInt16, token: Data, count: Int, timeout: Duration, family: AddressFamily) {
        self.identifier = identifier
        self.token = token
        self.count = count
        self.timeout = timeout
        self.family = family
    }

    mutating func recordSent(sequence: UInt16, at time: Duration) {
        requests[sequence] = Request(sentAt: time, rtt: nil)
    }

    /// Counts the datagram only if it's an echo reply of our address family with our identifier, one of
    /// our sequence numbers and our payload token, it's the first reply for that sequence, and it came
    /// back within the timeout.
    mutating func record(datagram: Data, at time: Duration) {
        guard let reply = EchoMessage(replyData: datagram, family: family),
              reply.identifier == identifier,
              reply.payload == token,
              let request = requests[reply.sequence],
              request.rtt == nil
        else {
            return
        }

        let rtt = time - request.sentAt

        guard rtt <= timeout else {
            return
        }

        requests[reply.sequence]?.rtt = rtt
        rtts.append(rtt)
    }

    /// Every request has been answered, so there's nothing left to wait for.
    var isComplete: Bool {
        rtts.count == count
    }

    /// `sent` is always `count`: a request that was meant to go out and got no reply is a loss, whether
    /// the send itself failed or the reply never came.
    var result: PingResult {
        PingResult(rtts: rtts, sent: count)
    }
}
