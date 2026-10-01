//
//  EchoMessage.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// An ICMP echo message: what a ping sends, and what comes back.
///
/// A request and its reply carry the same three fields; only the type byte differs. This type holds the
/// fields and converts them to and from the bytes on the wire (RFC 792 for IPv4, RFC 4443 for IPv6).
/// Both directions have an 8-byte header followed by the payload. Multi-byte fields are big-endian.
///
///     offset  0     1     2–3        4–5          6–7        8…
///             type  code  checksum   identifier   sequence   payload
public struct EchoMessage: Sendable, Equatable {
    public var identifier: UInt16
    public var sequence: UInt16
    public var payload: Data

    public init(identifier: UInt16, sequence: UInt16, payload: Data) {
        self.identifier = identifier
        self.sequence = sequence
        self.payload = payload
    }
}

// MARK: - Encoding

public extension EchoMessage {
    /// The bytes to send as an echo request.
    /// IPv4: type 8 with the RFC 1071 checksum. IPv6: type 128, checksum 0 (the kernel fills it in).
    func requestData(family: AddressFamily) -> Data {
        encoded(type: family == .ipv4 ? MessageType.echoRequestV4 : MessageType.echoRequestV6, family: family)
    }
}

extension EchoMessage {
    /// The bytes of an echo reply carrying this message, without an IP header (the way an ICMPv6 socket
    /// delivers it). Only tests need it, to play the remote host.
    func replyData(family: AddressFamily) -> Data {
        encoded(type: family == .ipv4 ? MessageType.echoReplyV4 : MessageType.echoReplyV6, family: family)
    }

    private func encoded(type: UInt8, family: AddressFamily) -> Data {
        var bytes: [UInt8] = []
        bytes.append(type)
        bytes.append(0) // code
        bytes.appendBigEndian(UInt16(0)) // checksum, filled in below
        bytes.appendBigEndian(identifier)
        bytes.appendBigEndian(sequence)
        bytes.append(contentsOf: payload)

        if family == .ipv4 {
            bytes.setBigEndian(Self.checksum(Data(bytes)), at: Field.checksum)
        }

        return Data(bytes)
    }
}

// MARK: - Decoding

public extension EchoMessage {
    /// Parses an echo reply, or returns nil if `data` isn't one.
    /// IPv4: strips the IP header by its header-length nibble, accepts type 0 only.
    /// IPv6: no header, accepts type 129 only (which also skips our own type-128 request on `::1`).
    init?(replyData data: Data, family: AddressFamily) {
        let bytes = [UInt8](data)
        let icmp: [UInt8]
        let expectedType: UInt8

        switch family {
        case .ipv4:
            // Darwin delivers IPv4 replies with their IP header. Its total-length field isn't reliable
            // here (it arrives in host byte order), so only the header-length nibble is used.
            guard let headerLength = Self.ipv4HeaderLength(of: bytes) else {
                return nil
            }

            icmp = Array(bytes.dropFirst(headerLength))
            expectedType = MessageType.echoReplyV4

        case .ipv6:
            icmp = bytes
            expectedType = MessageType.echoReplyV6
        }

        self.init(icmp: icmp, type: expectedType)
    }
}

extension EchoMessage {
    /// Parses an echo request as it goes out: no IP header, type 8 (IPv4) or 128 (IPv6). Only tests need
    /// it, to read what a pinger sent when they play the remote host.
    init?(requestData data: Data, family: AddressFamily) {
        self.init(
            icmp: [UInt8](data),
            type: family == .ipv4 ? MessageType.echoRequestV4 : MessageType.echoRequestV6
        )
    }

    /// Reads the fields of an ICMP echo message that starts at the first byte, if it has the given type.
    private init?(icmp: [UInt8], type: UInt8) {
        guard icmp.count >= Field.payload,
              icmp[Field.type] == type,
              icmp[Field.code] == 0
        else {
            return nil
        }

        self.init(
            identifier: icmp.bigEndianUInt16(at: Field.identifier),
            sequence: icmp.bigEndianUInt16(at: Field.sequence),
            payload: Data(icmp.dropFirst(Field.payload))
        )
    }
}

// MARK: - Wire format

extension EchoMessage {
    /// Byte offsets of the header fields.
    enum Field {
        static let type = 0
        static let code = 1
        static let checksum = 2
        static let identifier = 4
        static let sequence = 6
        static let payload = 8
    }

    enum MessageType {
        static let echoReplyV4: UInt8 = 0
        static let echoRequestV4: UInt8 = 8
        static let echoRequestV6: UInt8 = 128
        static let echoReplyV6: UInt8 = 129
    }

    /// The smallest IPv4 header: 5 words of 4 bytes.
    static let minimumIPv4HeaderLength = 20

    /// The length in bytes of the IPv4 header at the start of `bytes`, or nil if it isn't one.
    ///
    /// The first byte holds two 4-bit values: the IP version (high half) and the header length in
    /// 4-byte words (low half). `0x45` means IPv4 with a 5-word, 20-byte header.
    static func ipv4HeaderLength(of bytes: [UInt8]) -> Int? {
        guard let first = bytes.first else {
            return nil
        }

        let version = first >> 4
        let headerLength = Int(first & 0x0F) * 4

        guard version == 4, headerLength >= minimumIPv4HeaderLength else {
            return nil
        }

        return headerLength
    }

    /// The RFC 1071 Internet checksum.
    ///
    /// Add up the data as 16-bit big-endian words (an odd last byte is padded with a zero), fold every
    /// carry above 16 bits back into the low 16 bits, and invert the result. A packet that contains its
    /// own correct checksum therefore sums to 0xFFFF, and its checksum comes out as 0.
    static func checksum(_ data: Data) -> UInt16 {
        var bytes = [UInt8](data)
        if !bytes.count.isMultiple(of: 2) {
            bytes.append(0)
        }

        var sum: UInt32 = 0
        for index in stride(from: 0, to: bytes.count, by: 2) {
            sum += UInt32(bytes.bigEndianUInt16(at: index))
        }

        while sum > 0xFFFF {
            let carry = sum >> 16
            sum = (sum & 0xFFFF) + carry
        }

        return ~UInt16(sum)
    }
}
