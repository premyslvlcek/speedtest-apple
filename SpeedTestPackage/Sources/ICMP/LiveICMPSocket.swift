//
//  LiveICMPSocket.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Darwin
import Dispatch
import Foundation

/// The real socket: an unprivileged ICMP datagram socket, `connect()`ed to one address and read by a
/// `DispatchSourceRead`.
enum LiveICMPSocket {
    enum Failure: Error, Equatable {
        case open(Int32)
        case connect(Int32)
        case send(Int32)
    }

    static let open: SocketOpener = { address, onDatagram in
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
            close(descriptor)
            throw Failure.connect(code)
        }

        // Non-blocking, so draining the socket in the read handler stops when it's empty. recv() also passes
        // MSG_DONTWAIT, so a read can never block even if this flag were lost.
        let flags = fcntl(descriptor, F_GETFL)

        guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
            let code = errno
            close(descriptor)
            throw Failure.open(code)
        }

        // The receive time is taken on this queue, so it runs at the same priority as the rest of a ping.
        let source = DispatchSource.makeReadSource(
            fileDescriptor: descriptor,
            queue: DispatchQueue(label: "ICMP.LiveICMPSocket", qos: .userInitiated)
        )

        source.setEventHandler {
            // Drain everything that's waiting; the handler runs again when more arrives.
            var buffer = [UInt8](repeating: 0, count: 2048)

            while true {
                let length = recv(descriptor, &buffer, buffer.count, MSG_DONTWAIT)

                guard length > 0 else {
                    break
                }

                onDatagram(Data(buffer[0 ..< length]))
            }
        }

        source.setCancelHandler {
            close(descriptor)
        }

        source.activate()

        return ICMPSocket(
            send: { packet in
                let sent = packet.withUnsafeBytes { raw in
                    Darwin.send(descriptor, raw.baseAddress, raw.count, 0)
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
}
