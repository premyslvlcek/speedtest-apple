//
//  TransferMeterLive.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import ICMP
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
                // Only our own cancellation ends quietly; a cancellation from under the meter is a failure.
                continuation.finish(throwing: Task.isCancelled ? nil : Self.mapping(error) ?? .transferFailed)
            }
        }
        continuation.onTermination = { _ in
            measurement.cancel()
        }
        return stream
    }

    /// A failed start is mapped by its connection's error, so an offline device is `.offline` and any other failure
    /// `.transferFailed`. A stall, like every error that isn't a `URLError`, maps to `.transferFailed`; after t0 the
    /// error is already a `SpeedTestError`.
    static func mapping(_ error: any Error) -> SpeedTestError? {
        if case let TransferStartFailure.failed(connectionError) = error {
            return SpeedTestError.mapping(connectionError)
        }
        return SpeedTestError.mapping(error)
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
        let (duration, averageFrom) = switch direction {
        case .download:
            (configuration.downloadDuration, Duration.zero)

        case .upload:
            // Upload bytes count when handed to the network stack, which takes up to 2 MiB per connection ahead of
            // the line. The head start stays about the same all along, so leaving the first second out (no samples,
            // and an average from its end) cancels it.
            (configuration.uploadDuration, configuration.uploadWarmUp)
        }
        do {
            try await sample(handle, for: duration, averageFrom: averageFrom, onSample: onSample)
        } catch SpeedTestError.connectionLost where direction == .upload && handle.wasRefused() {
            // Upload bytes count as they're sent, so a server that refuses the upload does so after the first
            // byte. That's an upload that couldn't run, not a lost connection: the run still finishes.
            throw SpeedTestError.transferFailed
        }
    }

    /// Samples from t0 while watching the network. The watch starts here, at the first byte, so only a change
    /// during the transfer counts.
    private func sample(
        _ handle: TransferHandle,
        for duration: Duration,
        averageFrom: Duration,
        onSample: @escaping @Sendable (ThroughputSample) -> Void
    ) async throws {
        let stopwatch = Stopwatch(clock: clock)
        // Bytes start where time starts: whatever was counted before (the first chunk, and anything that arrived
        // while the meter got going) isn't measured.
        let bytesAtStart = handle.totalBytes()
        let changes = network.interfaceChanges()

        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in changes {
                    throw SpeedTestError.networkChanged
                }
                // The monitor stopped without a change: let the sampling finish alone.
                return false
            }
            group.addTask {
                try await tick(
                    handle,
                    stopwatch: stopwatch,
                    bytesAtStart: bytesAtStart,
                    for: duration,
                    averageFrom: averageFrom,
                    onSample: onSample
                )
                return true
            }

            while let isFinished = try await group.next() {
                if isFinished {
                    group.cancelAll()
                    return
                }
            }
        }
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
        let outcome = OSAllocatedUnfairLock(initialState: FirstByteOutcome.waiting)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await clock.sleep(for: stallTimeout)
                // Only one side decides: the timeout cancels the connections only if the first byte hasn't
                // claimed the outcome already, and once the timeout has claimed it, a first byte that arrives later is
                // still a stall.
                if outcome.withLock({ $0.claim(.timedOut) }) {
                    handle.cancel()
                }
            }
            defer { group.cancelAll() }

            do {
                try await handle.firstByte()
            } catch {
                let cancelledByTimeout = outcome.withLock { $0 } == .timedOut && SpeedTestError.mapping(error) == nil
                throw cancelledByTimeout ? TransferStartFailure.stalled : TransferStartFailure.failed(error)
            }
            guard outcome.withLock({ $0.claim(.firstByte) }) else {
                throw TransferStartFailure.stalled
            }
        }
    }

    private func tick(
        _ handle: TransferHandle,
        stopwatch: Stopwatch,
        bytesAtStart: Int64,
        for duration: Duration,
        averageFrom: Duration,
        onSample: @Sendable (ThroughputSample) -> Void
    ) async throws {
        var sampler = ThroughputSampler(window: configuration.speedWindow, averageFrom: averageFrom)
        var schedule = SampleSchedule(interval: configuration.sampleInterval, duration: duration)

        while true {
            let target = schedule.nextTarget
            let wait = target - stopwatch.elapsed()
            if wait > .zero {
                try await clock.sleep(for: wait)
            }
            try Task.checkCancellation()
            guard handle.isAlive() else { throw SpeedTestError.connectionLost }

            let elapsed = stopwatch.elapsed()
            let wakeUp = schedule.wake(at: elapsed)
            // The speeds use the time the bytes were actually read at; a late last wake-up still shows as the
            // duration, but doesn't count the extra bytes over the shorter time.
            var sample = sampler.add(elapsed: elapsed, totalBytes: handle.totalBytes() - bytesAtStart)
            sample.elapsed = wakeUp.elapsed
            // Readings during the warm-up are taken, so the window and the average start from its end, but not
            // shown: they'd show the head start as speed. The tick decides, not the wake-up: a real clock wakes a
            // little late, so the tick at the warm-up's end would otherwise be shown.
            if target > averageFrom {
                onSample(sample)
            }
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

/// Which came first while waiting for the first byte. Moved out of `waiting` once, under a lock.
enum FirstByteOutcome: Equatable, Sendable {
    case waiting
    case firstByte
    case timedOut

    /// Takes the outcome if nothing has yet. Returns whether this call decided it.
    mutating func claim(_ claimed: Self) -> Bool {
        guard self == .waiting else {
            return false
        }

        self = claimed
        return true
    }
}
