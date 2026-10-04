//
//  AddressResolver.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Darwin
import Dispatch
import Foundation

/// Looks up a host name with `getaddrinfo`.
///
/// `PF_UNSPEC` with `AI_DEFAULT` is what lets the system synthesize an IPv6 address on an IPv6-only
/// (NAT64) mobile network; narrower hints suppress that.
enum AddressResolver {
    static func resolve(_ host: String) async -> ResolvedAddress? {
        // getaddrinfo blocks, so it runs on a dispatch queue, off Swift's cooperative thread pool. It can't be
        // interrupted: a cancelled ping waits for it, then returns without sending anything. Stop doesn't wait: the
        // reducer resets at once, and TCA drops whatever the cancelled effect sends later.
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: lookUp(host))
            }
        }
    }

    private static func lookUp(_ host: String) -> ResolvedAddress? {
        var hints = addrinfo()
        hints.ai_family = PF_UNSPEC
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_flags = AI_DEFAULT

        var list: UnsafeMutablePointer<addrinfo>?

        guard getaddrinfo(host, nil, &hints, &list) == 0 else {
            return nil
        }

        defer {
            freeaddrinfo(list)
        }

        var entry = list

        while let current = entry {
            let info = current.pointee

            if let address = info.ai_addr, info.ai_family == AF_INET || info.ai_family == AF_INET6 {
                return ResolvedAddress(
                    family: info.ai_family == AF_INET ? .ipv4 : .ipv6,
                    sockaddr: Data(bytes: address, count: Int(info.ai_addrlen))
                )
            }

            entry = info.ai_next
        }

        return nil
    }
}
