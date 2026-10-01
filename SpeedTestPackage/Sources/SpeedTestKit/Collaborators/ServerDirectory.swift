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
/// Both endpoints throw a `SpeedTestError` (`.offline`, `.rateLimited` or `.directoryUnavailable`), or
/// `CancellationError` when the run was stopped. Neither is ever retried automatically.
@DependencyClient
public struct ServerDirectory: Sendable {
    /// `GET /api/v2/servers?secured=only`, with the coordinate when there is one. Without it the directory
    /// locates the caller by IP (approximate mode).
    public var fetch: @Sendable (_ near: Coordinate?) async throws -> [Server]
    /// `POST /api/v1/tokens`: a fresh token for this run's transfers.
    public var token: @Sendable () async throws -> TransferToken
}

public extension DependencyValues {
    @DependencyEntry(
        liveValue: ServerDirectory.live(timeout: SpeedTestConfiguration.standard.directoryTimeout),
        previewValue: ServerDirectory.scripted
    )
    var serverDirectory = ServerDirectory()
}
