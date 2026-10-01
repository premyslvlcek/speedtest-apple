//
//  TransferServiceLive.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

public extension TransferService {
    /// Parallel HTTPS connections to one server. The handle exposes a byte counter only; the transfer meter owns
    /// the clock and the sampling.
    static let live = TransferService(start: { server, direction, token, configuration in
        let session = TransferSession(
            server: server,
            direction: direction,
            token: token,
            configuration: configuration
        )
        session.start()
        return TransferHandle(
            firstByte: { try await session.waitForFirstByte() },
            totalBytes: { session.totalBytes },
            isAlive: { session.isAlive },
            cancel: { session.cancel() }
        )
    })
}
