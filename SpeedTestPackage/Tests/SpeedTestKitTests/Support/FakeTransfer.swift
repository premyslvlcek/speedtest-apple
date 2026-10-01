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
    }

    private struct State {
        var reads = 0
        var cancelCount = 0
        var isCancelled = false
        var waiter: CheckedContinuation<Void, any Error>?
    }

    let firstByteBehavior: FirstByte
    let bytesPerRead: Int64
    /// `isAlive()` returns false once `totalBytes()` has been read this many times. nil means always alive.
    let aliveForReads: Int?
    /// Called with n on the n-th `totalBytes()` read, before it returns.
    let onRead: @Sendable (Int) -> Void
    private let state = LockIsolated(State())
    private let cancellations: AsyncStream<Void>.Continuation
    /// Yields once for every `cancel()` call.
    let cancelled: AsyncStream<Void>

    init(
        firstByte: FirstByte = .immediate,
        // 1.25 MB per read: at the standard sample interval, a steady 40 Mbps.
        bytesPerRead: Int64 = 1_250_000,
        aliveForReads: Int? = nil,
        onRead: @escaping @Sendable (Int) -> Void = { _ in }
    ) {
        self.firstByteBehavior = firstByte
        self.bytesPerRead = bytesPerRead
        self.aliveForReads = aliveForReads
        self.onRead = onRead
        (cancelled, cancellations) = AsyncStream.makeStream()
    }

    var reads: Int {
        state.value.reads
    }

    var cancelCount: Int {
        state.value.cancelCount
    }

    var handle: TransferHandle {
        TransferHandle(
            firstByte: { try await self.waitForFirstByte() },
            totalBytes: { self.read() },
            isAlive: { self.isAlive },
            cancel: { self.cancel() }
        )
    }

    /// Matches the handle's contract: false once every connection has failed or been cancelled.
    private var isAlive: Bool {
        switch firstByteBehavior {
        case .fails:
            false

        case .never:
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
        onRead(count)
        return Int64(count) * bytesPerRead
    }

    private func waitForFirstByte() async throws {
        switch firstByteBehavior {
        case .immediate:
            return

        case let .fails(error):
            throw error

        case .never:
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
        state.withValue { $0.cancelCount += 1 }
        cancellations.yield()
        resumeWaiter()
    }

    private func resumeWaiter() {
        let waiter = state.withValue { state in
            state.isCancelled = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume(throwing: URLError(.cancelled))
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
