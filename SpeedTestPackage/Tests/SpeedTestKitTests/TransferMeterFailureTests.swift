//
//  TransferMeterFailureTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Clocks
import Foundation
import SpeedTestKit
import Testing
import TestSupport

/// Every test reads the stream in its own body, so the time limit can cancel a test that hangs.
@Suite(.mainSerialExecutor, .timeLimit(.minutes(1))) struct TransferMeterFailureTests {
    // MARK: - Before the first byte

    /// A cancellation the meter didn't ask for (the session cancelled under it) is a failure, not a quiet end: a
    /// quiet end would look like a finished transfer with no samples and skip the failover.
    @Test func aCancellationNobodyAskedForIsATransferFailure() async {
        let transfers = FakeTransferService([FakeTransfer(firstByte: .fails(URLError(.cancelled)))])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .transferFailed)
    }

    @Test func noFirstByteBeforeTheStallTimeoutIsATransferFailure() async {
        let transfers = FakeTransferService([FakeTransfer(firstByte: .never)])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .transferFailed)
    }

    /// The timeout fires and cancels the connections just as a real error arrives: the error wins, so an offline
    /// device still reads as offline, not as a stalled server.
    @Test func aRealErrorBeatsTheTimeoutItCoincidesWith() async {
        let transfers = FakeTransferService([
            FakeTransfer(firstByte: .whenCancelled(.failure(URLError(.notConnectedToInternet))))
        ])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .offline)
    }

    /// A first byte that lands just as the timeout has cancelled every connection doesn't count: there is nothing
    /// left to measure.
    @Test func aByteAfterTheTimeoutCancelledTheConnectionsIsAStall() async {
        let transfers = FakeTransferService([FakeTransfer(firstByte: .whenCancelled(.success(())))])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .transferFailed)
        #expect(measurement.samples.isEmpty)
    }

    @Test func anOfflineDeviceIsOffline() async {
        let transfers = FakeTransferService([FakeTransfer(firstByte: .fails(URLError(.notConnectedToInternet)))])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        // Mapped by the connection's error, not by the meter's wrapper around it (that would be `.transferFailed`).
        #expect(measurement.speedTestError == .offline)
        #expect(measurement.samples.isEmpty)
    }

    // MARK: - After the first byte

    @Test func whenEveryConnectionHasFailedTheTransferIsLost() async {
        // One read when the clock starts, then eight samples.
        let transfers = FakeTransferService([FakeTransfer(aliveForReads: 9)])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .connectionLost)
        #expect(measurement.samples.count == 8)
    }

    /// Upload bytes count as they're sent, so a server that refuses the upload (401, 413, 5xx) does so after the
    /// first byte. That's a failed upload, not a lost connection: the run still finishes. A download that loses its
    /// connections the same way stays a lost connection.
    @Test(arguments: [
        (TransferDirection.upload, SpeedTestError.transferFailed),
        (.download, .connectionLost)
    ])
    func aServerThatRefusesEveryConnectionAfterTheFirstByte(
        direction: TransferDirection,
        expected: SpeedTestError
    ) async {
        let transfers = FakeTransferService([FakeTransfer(aliveForReads: 3, endsRefused: true)])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, direction, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == expected)
    }

    /// The `TestClock` never advances, so after the first byte the meter sleeps towards its first tick. The
    /// monitor's subscription marks the moment the watch has started.
    @Test func aNetworkChangeAfterTheFirstByteInterruptsTheTransfer() async {
        let monitor = FakeNetworkMonitor()
        let meter = makeMeter(network: monitor.monitor, clock: TestClock())
        let samples = meter.measure(MeterFixtures.server, .download, MeterFixtures.token)
        var subscriptions = monitor.subscriptions.makeAsyncIterator()
        await subscriptions.next()

        monitor.changeInterface()
        let measurement = await samples.collect()

        #expect(measurement.speedTestError == .networkChanged)
    }

    @Test func aNetworkChangeBeforeTheFirstByteDoesNotCount() async {
        let monitor = FakeNetworkMonitor()
        let transfers = FakeTransferService()
        // The change is reported while the transfer is starting, before its first byte.
        let transfer = TransferService(start: { server, direction, token, configuration in
            monitor.changeInterface()
            return transfers.service.start(server, direction, token, configuration)
        })
        let meter = makeMeter(transfer: transfer, network: monitor.monitor)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.error == nil)
        #expect(monitor.watchCount == 1)
    }

    // MARK: - Stop

    @Test func endingTheIterationCancelsTheTransferQuietly() async {
        let transfers = FakeTransferService([FakeTransfer()])
        let monitor = FakeNetworkMonitor()
        let meter = makeMeter(transfer: transfers.service, network: monitor.monitor, clock: TestClock())
        let samples = meter.measure(MeterFixtures.server, .download, MeterFixtures.token)
        var subscriptions = monitor.subscriptions.makeAsyncIterator()

        let measurement = await withTaskGroup(of: Measurement.self) { group in
            group.addTask { await samples.collect() }
            await subscriptions.next()
            group.cancelAll()
            return await group.next() ?? Measurement()
        }

        #expect(measurement.error == nil)
        var cancellations = transfers.transfers[0].cancelled.makeAsyncIterator()
        await cancellations.next()
    }
}
