//
//  TransferMeterLive.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import os

public extension TransferMeter {
    /// The meter on the registered `transferService`, `networkMonitor` and `continuousClock`, resolved when this
    /// value is created.
    static var live: TransferMeter {
        @Dependency(\.transferService) var transfer
        @Dependency(\.networkMonitor) var network
        @Dependency(\.continuousClock) var clock

        let measurement = TransferMeasurement(
            transfer: transfer,
            network: network,
            clock: clock,
            configuration: .standard
        )
        return TransferMeter(measure: { server, direction, token in
            measurement.run(on: server, direction, token: token)
        })
    }
}

/// Why a transfer never reached its first byte.
enum TransferStartFailure: Error {
    /// Nothing arrived within the stall timeout.
    case stalled
    /// Every connection failed first; this is the last connection's error.
    case failed(any Error)
}

/// The live meter's logic. The hot path (byte counting) never goes through it; it samples a lock-protected
/// counter on its own tick.
struct TransferMeasurement: Sendable {
    let transfer: TransferService
    let network: NetworkMonitor
    let clock: any Clock<Duration>
    let configuration: SpeedTestConfiguration

    /// Starts the transfer. Ending the stream's iteration cancels it.
    func run(
        on server: Server,
        _ direction: TransferDirection,
        token: TransferToken
    ) -> AsyncThrowingStream<ThroughputSample, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(
            of: ThroughputSample.self,
            throwing: (any Error).self
        )
        let measurement = Task {
            do {
                try await measure(on: server, direction, token: token) { continuation.yield($0) }
                continuation.finish()
            } catch {
                continuation.finish(throwing: Task.isCancelled ? nil : SpeedTestError.mapping(error))
            }
        }
        continuation.onTermination = { _ in
            measurement.cancel()
        }
        return stream
    }

    /// t0 is the first byte; a sample every `sampleInterval` after it, the last one at exactly t0 + the duration.
    private func measure(
        on server: Server,
        _ direction: TransferDirection,
        token: TransferToken,
        onSample: @escaping @Sendable (ThroughputSample) -> Void
    ) async throws {
        let handle = transfer.start(server, direction, token, configuration.transfer)
        defer { handle.cancel() }

        try await waitForFirstByte(handle)
        let duration = switch direction {
        case .download:
            configuration.downloadDuration

        case .upload:
            configuration.uploadDuration
        }
        try await tick(handle, stopwatch: Stopwatch(clock: clock), for: duration, onSample: onSample)
    }

    /// Waits for the first byte, for at most `stallTimeout`. When the time runs out it cancels the handle,
    /// which makes a pending `firstByte()` throw.
    ///
    /// The timer and the first byte can land together, so the outcome is decided by what actually happened,
    /// not by which task finished first: a real error from `firstByte()` always wins, and a timeout counts
    /// only if it cancelled the connections.
    private func waitForFirstByte(_ handle: TransferHandle) async throws {
        let clock = self.clock
        let stallTimeout = configuration.stallTimeout
        let timedOut = OSAllocatedUnfairLock(initialState: false)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await clock.sleep(for: stallTimeout)
                try Task.checkCancellation()
                timedOut.withLock { $0 = true }
                handle.cancel()
            }
            defer { group.cancelAll() }

            do {
                try await handle.firstByte()
            } catch {
                let cancelledByTimeout = timedOut.withLock { $0 } && SpeedTestError.mapping(error) == nil
                throw cancelledByTimeout ? TransferStartFailure.stalled : TransferStartFailure.failed(error)
            }
            if timedOut.withLock({ $0 }), !handle.isAlive() {
                throw TransferStartFailure.stalled
            }
        }
    }

    private func tick(
        _ handle: TransferHandle,
        stopwatch: Stopwatch,
        for duration: Duration,
        onSample: @Sendable (ThroughputSample) -> Void
    ) async throws {
        var sampler = ThroughputSampler(window: configuration.speedWindow)
        var schedule = SampleSchedule(interval: configuration.sampleInterval, duration: duration)

        while true {
            let wait = schedule.nextTarget - stopwatch.elapsed()
            if wait > .zero {
                try await clock.sleep(for: wait)
            }
            try Task.checkCancellation()

            let wakeUp = schedule.wake(at: stopwatch.elapsed())
            onSample(sampler.add(elapsed: wakeUp.elapsed, totalBytes: handle.totalBytes()))
            if wakeUp.isLast {
                return
            }
        }
    }
}

/// When to sample: every `interval` after t0, the last one at exactly `duration`.
struct SampleSchedule {
    let interval: Duration
    let duration: Duration
    private var tick = 1

    init(interval: Duration, duration: Duration) {
        self.interval = interval
        self.duration = duration
    }

    /// The next moment to sample at, measured from t0. A multiple of the interval, so the ticks don't drift.
    var nextTarget: Duration {
        min(interval * tick, duration)
    }

    /// Records a wake-up `elapsed` after t0. The sample is reported at most at `duration`. After a late wake-up the
    /// ticks that have passed are skipped, not sampled all at once.
    mutating func wake(at elapsed: Duration) -> (elapsed: Duration, isLast: Bool) {
        let reported = min(elapsed, duration)
        tick = Int((reported / interval).rounded(.down)) + 1
        return (reported, reported >= duration)
    }
}
