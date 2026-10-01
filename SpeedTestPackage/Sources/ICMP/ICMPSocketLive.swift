//
//  ICMPSocketLive.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Darwin
import Dispatch
import Foundation

extension ICMPSocket {
    /// Why the live socket couldn't be opened, connected or written to, with the `errno` value.
    enum Failure: Error {
        case open(Int32)
        case connect(Int32)
        case send(Int32)
    }

    /// The real socket: an unprivileged ICMP datagram socket, `connect()`ed to the address and read by a
    /// `DispatchSourceRead`. Matches `SocketOpener`, so `Pinger` takes it as `ICMPSocket.live`.
    static func live(
        connectingTo address: ResolvedAddress,
        onDatagram: @escaping @Sendable (Data) -> Void
    ) throws -> ICMPSocket {
        let descriptor: Int32 = switch address.family {
        case .ipv4:
            socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)

        case .ipv6:
            socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
        }

        guard descriptor >= 0 else {
            throw Failure.open(errno)
        }

        // connect() makes the kernel deliver only this peer's replies. If there's no route, it fails here,
        // and the pinger reports "no reply".
        let connected = address.sockaddr.withUnsafeBytes { raw -> Int32 in
            guard let base = raw.baseAddress else {
                return -1
            }

            // The bytes are a sockaddr_in or sockaddr_in6, which both start with a sockaddr header.
            return connect(descriptor, base.assumingMemoryBound(to: sockaddr.self), socklen_t(raw.count))
        }

        guard connected == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw Failure.connect(code)
        }

        let source = readSource(for: descriptor, onDatagram: onDatagram)

        return ICMPSocket(
            send: { packet in
                let sent = packet.withUnsafeBytes { raw in
                    Darwin.send(descriptor, raw.baseAddress, raw.count, MSG_DONTWAIT)
                }

                guard sent == packet.count else {
                    throw Failure.send(errno)
                }
            },
            close: {
                source.cancel()
            }
        )
    }

    /// The largest datagram read at once. An echo reply with our 16-byte token is 44 bytes including its IPv4
    /// header, so this leaves room for IP options and anything else the peer might send.
    private static let maximumDatagramLength = 2048

    /// Reads every datagram as it arrives and passes it to `onDatagram`, then closes the descriptor once the
    /// source is cancelled (dispatch runs the cancel handler only after any running read has finished).
    private static func readSource(
        for descriptor: Int32,
        onDatagram: @escaping @Sendable (Data) -> Void
    ) -> any DispatchSourceRead {
        // The receive time is taken on this queue, so it runs at the same priority as the rest of a ping.
        let source = DispatchSource.makeReadSource(
            fileDescriptor: descriptor,
            queue: DispatchQueue(label: "ICMP.ICMPSocket.live", qos: .userInitiated)
        )

        source.setEventHandler {
            // Drain everything that's waiting; the handler runs again when more arrives. MSG_DONTWAIT makes the
            // last recv() return at once when the socket is empty, instead of blocking this queue.
            var buffer = [UInt8](repeating: 0, count: maximumDatagramLength)

            while true {
                let length = recv(descriptor, &buffer, buffer.count, MSG_DONTWAIT)

                guard length > 0 else {
                    break
                }

                onDatagram(Data(buffer[0 ..< length]))
            }
        }

        source.setCancelHandler {
            Darwin.close(descriptor)
        }

        source.activate()
        return source
    }
}
