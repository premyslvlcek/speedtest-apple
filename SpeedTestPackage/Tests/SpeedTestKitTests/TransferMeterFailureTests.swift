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

    /// A non-2xx answer and a TLS failure: the two ways a server can fail before the first byte.
    @Test(arguments: [
        HTTPStatusError(statusCode: 429) as any Error,
        URLError(.serverCertificateUntrusted)
    ])
    func aFailedStartIsATransferFailure(error: any Error) async {
        let transfers = FakeTransferService([FakeTransfer(firstByte: .fails(error))])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .transferFailed)
        #expect(measurement.samples.isEmpty)
    }

    @Test func nothingForThreeSecondsIsATransferFailure() async {
        let transfers = FakeTransferService([FakeTransfer(firstByte: .never)])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .transferFailed)
        #expect(transfers.transfers[0].cancelCount >= 1)
    }

    @Test func anOfflineDeviceIsOffline() async {
        let transfers = FakeTransferService([FakeTransfer(firstByte: .fails(URLError(.notConnectedToInternet)))])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .offline)
    }

    // MARK: - After the first byte

    @Test func whenEveryConnectionHasFailedTheTransferIsLost() async {
        let transfers = FakeTransferService([FakeTransfer(aliveForReads: 8)])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.speedTestError == .connectionLost)
        #expect(measurement.samples.count == 8)
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
