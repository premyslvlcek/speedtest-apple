//
//  TransferService.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import DependenciesMacros

/// A running transfer over parallel connections. It has no clock and does no sampling:
/// the engine reads `totalBytes()` on its own tick.
public struct TransferHandle: Sendable {
    /// Returns at the first byte. Throws the last connection's error if every connection fails first.
    public var firstByte: @Sendable () async throws -> Void
    /// The bytes counted so far. Non-blocking: the engine reads it on every sample tick.
    public var totalBytes: @Sendable () -> Int64
    /// False once every connection has failed.
    public var isAlive: @Sendable () -> Bool
    public var cancel: @Sendable () -> Void

    public init(
        firstByte: @escaping @Sendable () async throws -> Void,
        totalBytes: @escaping @Sendable () -> Int64,
        isAlive: @escaping @Sendable () -> Bool,
        cancel: @escaping @Sendable () -> Void
    ) {
        self.firstByte = firstByte
        self.totalBytes = totalBytes
        self.isAlive = isAlive
        self.cancel = cancel
    }
}

public extension TransferHandle {
    /// A handle that never starts: `firstByte` throws `error`.
    static func failing(_ error: any Error) -> TransferHandle {
        TransferHandle(
            firstByte: { throw error },
            totalBytes: { 0 },
            isAlive: { false },
            cancel: {}
        )
    }
}

/// Starts download or upload connections to one server.
@DependencyClient
public struct TransferService: Sendable {
    public var start: @Sendable (
        _ server: Server,
        _ direction: TransferDirection,
        _ token: TransferToken,
        _ configuration: TransferConfiguration
    ) -> TransferHandle = { _, _, _, _ in .failing(CancellationError()) }
}

public extension DependencyValues {
    @DependencyEntry(liveValue: TransferService.live)
    var transferService = TransferService()
}
