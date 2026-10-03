//
//  FakeTransfer.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ConcurrencyExtras
import Foundation
import SpeedTestKit

/// One controllable transfer. `totalBytes()` returns `bytesPerRead × n` on its n-th call, so with an
/// `ImmediateClock` (one read per tick) every sample is known in advance.
final class FakeTransfer: Sendable {
    enum FirstByte: Sendable {
        /// Returns at once.
        case immediate
        /// Suspends until the handle is cancelled (or the calling task is), then throws `URLError(.cancelled)`.
        case never
        /// Throws this error at once, as if every connection failed.
        case fails(any Error)
        /// Suspends until the handle is cancelled, then ends with this result: a real error or a late byte that
        /// lands just as the stall timeout cancels the connections.
        case whenCancelled(Result<Void, any Error>)
    }

    private struct State {
        var reads = 0
        var isCancelled = false
        var waiter: CheckedContinuation<Void, any Error>?
    }

    let firstByteBehavior: FirstByte
    let bytesPerRead: Int64
    /// `isAlive()` returns false once `totalBytes()` has been read this many times. nil means always alive.
    let aliveForReads: Int?
    /// When every connection has gone, whether the server refused them (a non-2xx answer).
    let endsRefused: Bool
    /// Already counted when the first byte arrives, on top of `bytesPerRead × n`.
    let bytesAtFirstByte: Int64
    /// Counted all at once by the first sample after t0 and kept from then on, like the chunk per connection the
    /// network stack takes at the start of an upload.
    let headStart: Int64
    private let state = LockIsolated(State())
    private let cancellations: AsyncStream<Void>.Continuation
    /// Yields once for every `cancel()` call.
    let cancelled: AsyncStream<Void>

    init(
        firstByte: FirstByte = .immediate,
        // 1.25 MB per read: at the standard sample interval, a steady 40 Mbps.
        bytesPerRead: Int64 = 1_250_000,
        aliveForReads: Int? = nil,
        endsRefused: Bool = false,
        bytesAtFirstByte: Int64 = 0,
        headStart: Int64 = 0
    ) {
        self.bytesAtFirstByte = bytesAtFirstByte
        self.headStart = headStart
        self.firstByteBehavior = firstByte
        self.bytesPerRead = bytesPerRead
        self.aliveForReads = aliveForReads
        self.endsRefused = endsRefused
        (cancelled, cancellations) = AsyncStream.makeStream()
    }

    var handle: TransferHandle {
        TransferHandle(
            firstByte: { try await self.waitForFirstByte() },
            totalBytes: { self.read() },
            isAlive: { self.isAlive },
            wasRefused: { self.endsRefused && !self.isAlive },
            cancel: { self.cancel() }
        )
    }

    /// Matches the handle's contract: false once every connection has failed or been cancelled.
    private var isAlive: Bool {
        switch firstByteBehavior {
        case .fails:
            false

        case .never, .whenCancelled:
            !state.value.isCancelled

        case .immediate:
            aliveForReads.map { state.value.reads < $0 } ?? true
        }
    }

    private func read() -> Int64 {
        guard case .immediate = firstByteBehavior else {
            return 0
        }
        let count = state.withValue {
            $0.reads += 1
            return $0.reads
        }
        // The first read is the one at t0.
        return bytesAtFirstByte + (count > 1 ? headStart : 0) + Int64(count) * bytesPerRead
    }

    private func waitForFirstByte() async throws {
        switch firstByteBehavior {
        case .immediate:
            return

        case let .fails(error):
            throw error

        case .never, .whenCancelled:
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let resumeNow = state.withValue {
                        guard !$0.isCancelled else {
                            return true
                        }
                        $0.waiter = continuation
                        return false
                    }
                    if resumeNow {
                        continuation.resume(throwing: URLError(.cancelled))
                    }
                }
            } onCancel: {
                self.resumeWaiter()
            }
        }
    }

    private func cancel() {
        cancellations.yield()
        resumeWaiter()
    }

    private func resumeWaiter() {
        let waiter = state.withValue { state in
            state.isCancelled = true
            defer { state.waiter = nil }
            return state.waiter
        }
        if case let .whenCancelled(result) = firstByteBehavior {
            waiter?.resume(with: result)
        } else {
            waiter?.resume(throwing: URLError(.cancelled))
        }
    }
}

/// Hands out prepared transfers in order, one per `start` call, and records every call.
final class FakeTransferService: Sendable {
    struct Start: Equatable, Sendable {
        let server: Server.ID
        let direction: TransferDirection
        let token: String
    }

    private let queue: LockIsolated<[FakeTransfer]>
    private let log = LockIsolated<[(start: Start, transfer: FakeTransfer)]>([])

    /// When `transfers` runs out, every further call gets a fresh `FakeTransfer()`.
    init(_ transfers: [FakeTransfer] = []) {
        queue = LockIsolated(transfers)
    }

    var starts: [Start] {
        log.value.map(\.start)
    }

    var transfers: [FakeTransfer] {
        log.value.map(\.transfer)
    }

    var service: TransferService {
        TransferService(start: { server, direction, token, _ in
            let transfer = self.queue.withValue { $0.isEmpty ? FakeTransfer() : $0.removeFirst() }
            self.log.withValue {
                $0.append((Start(server: server.id, direction: direction, token: token.value), transfer))
            }
            return transfer.handle
        })
    }
}
