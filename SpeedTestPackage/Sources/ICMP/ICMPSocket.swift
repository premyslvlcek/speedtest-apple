//
//  ICMPSocket.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// A looked-up address, ready for `connect()`.
struct ResolvedAddress: Sendable, Equatable {
    let family: AddressFamily
    /// A `sockaddr_in` or `sockaddr_in6`, as bytes.
    let sockaddr: Data
}

/// The seam between `Pinger` and the operating system. The live version wraps a real socket; tests use
/// a fake that answers synchronously.
struct ICMPSocket: Sendable {
    var send: @Sendable (Data) throws -> Void
    /// Closes the socket. Nothing may be sent after this.
    var close: @Sendable () -> Void
}

/// Opens a socket and `connect()`s it to the address. `onDatagram` is called for every datagram received,
/// synchronously from the read handler, so the caller can timestamp it there.
typealias SocketOpener = @Sendable (
    ResolvedAddress,
    _ onDatagram: @escaping @Sendable (Data) -> Void
) throws -> ICMPSocket
