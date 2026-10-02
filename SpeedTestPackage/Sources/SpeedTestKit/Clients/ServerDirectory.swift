//
//  ServerDirectory.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import DependenciesMacros

/// Ubiquiti's server directory at `sp-dir.uwn.com`.
///
/// Every endpoint throws a `SpeedTestError` (`.offline`, `.rateLimited` or `.directoryUnavailable`), or
/// `CancellationError` when the run was stopped. None is ever retried automatically.
@DependencyClient
public struct ServerDirectory: Sendable {
    /// `GET /api/v2/servers?secured=only`, with the coordinate when there is one. Without it the directory
    /// locates the caller by IP (approximate mode).
    public var fetch: @Sendable (_ near: Coordinate?) async throws -> [Server]
    /// `POST /api/v1/tokens`: a fresh token for this run's transfers.
    public var token: @Sendable () async throws -> TransferToken
    /// `GET /api/v1/ip`: the device's public address and its provider, shown next to the result.
    public var clientIP: @Sendable () async throws -> ClientIP
}

public extension DependencyValues {
    @DependencyEntry(
        liveValue: ServerDirectory.live(timeout: SpeedTestConfiguration.standard.directoryTimeout),
        previewValue: ServerDirectory.scripted
    )
    var serverDirectory = ServerDirectory()
}
