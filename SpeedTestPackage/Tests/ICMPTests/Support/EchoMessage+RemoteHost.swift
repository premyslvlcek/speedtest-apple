//
//  EchoMessage+RemoteHost.swift
//  ICMPTests
//
//  Created by Premysl Vlcek on 03.10.2026.
//

import Foundation

@testable import ICMP

/// What a test needs to play the remote host: read the request a pinger sent, and build the reply.
extension EchoMessage {
    /// Parses an echo request as it goes out: no IP header, type 8 (IPv4) or 128 (IPv6).
    init?(requestData data: Data, family: AddressFamily) {
        self.init(icmp: [UInt8](data), type: family == .ipv4 ? MessageType.echoRequestV4 : MessageType.echoRequestV6)
    }

    /// The bytes of an echo reply carrying this message, without an IP header (the way an ICMPv6 socket delivers it).
    func replyData(family: AddressFamily) -> Data {
        encoded(type: family == .ipv4 ? MessageType.echoReplyV4 : MessageType.echoReplyV6, family: family)
    }
}
