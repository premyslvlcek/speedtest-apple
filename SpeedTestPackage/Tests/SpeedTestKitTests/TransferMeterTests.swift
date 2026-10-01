//
//  TransferMeterTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Clocks
import Testing
import TestSupport

@testable import SpeedTestKit

/// With an `ImmediateClock` every sleep returns at once and moves the clock by exactly its duration, and the
/// fake transfer returns `bytesPerRead × n` on its n-th read, so every sample is known in advance.
@Suite(.mainSerialExecutor, .timeLimit(.minutes(1))) struct TransferMeterTests {
    /// 1.25 MB per 250 ms tick is 40 Mbps.
    let bytesPerRead: Int64 = 1_250_000
    let interval = SpeedTestConfiguration.standard.sampleInterval

    @Test func downloadSamplesEveryQuarterSecondForFifteenSeconds() async {
        let transfers = FakeTransferService([FakeTransfer(bytesPerRead: bytesPerRead)])
        let meter = makeMeter(transfer: transfers.service)

        let measurement = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(measurement.error == nil)
        // Every interval from the first byte to exactly 15 s: 60 samples, no drift.
        #expect(measurement.samples.map(\.elapsed) == (1 ... 60).map { interval * $0 })
        #expect(measurement.samples.last?.totalBytes == 60 * bytesPerRead)
    }

    @Test func uploadSamplesForTenSeconds() async {
        let meter = makeMeter()

        let measurement = await meter.measure(MeterFixtures.server, .upload, MeterFixtures.token).collect()

        #expect(measurement.samples.count == 40)
        #expect(measurement.samples.last?.elapsed == .seconds(10))
    }

    @Test func theTransferStartsWithTheGivenServerDirectionAndToken() async {
        let transfers = FakeTransferService()
        let meter = makeMeter(transfer: transfers.service)

        _ = await meter.measure(MeterFixtures.server, .upload, MeterFixtures.token).collect()

        #expect(transfers.starts == [
            FakeTransferService.Start(server: MeterFixtures.server.id, direction: .upload, token: "token-1")
        ])
    }

    @Test func theHandleIsCancelledWhenTheMeasurementEnds() async {
        let transfers = FakeTransferService()
        let meter = makeMeter(transfer: transfers.service)

        _ = await meter.measure(MeterFixtures.server, .download, MeterFixtures.token).collect()

        #expect(transfers.transfers.first?.cancelCount ?? 0 >= 1)
    }
}

@Suite struct SampleScheduleTests {
    var schedule = SampleSchedule(interval: .milliseconds(250), duration: .seconds(15))

    @Test mutating func onTimeTheNextTickFollows() {
        #expect(schedule.nextTarget == .milliseconds(250))

        let wakeUp = schedule.wake(at: .milliseconds(250))

        #expect(wakeUp == (.milliseconds(250), false))
        #expect(schedule.nextTarget == .milliseconds(500))
    }

    @Test mutating func aLateWakeUpSkipsTheTicksThatHavePassed() {
        let wakeUp = schedule.wake(at: .milliseconds(600))

        #expect(wakeUp == (.milliseconds(600), false))
        #expect(schedule.nextTarget == .milliseconds(750))
    }

    @Test mutating func aWakeUpPastTheEndIsTheLastSampleAtExactlyTheDuration() {
        let wakeUp = schedule.wake(at: .seconds(20))

        #expect(wakeUp == (.seconds(15), true))
    }

    @Test func theLastTargetIsTheDurationEvenOffTheInterval() {
        var schedule = SampleSchedule(interval: .seconds(4), duration: .seconds(10))

        _ = schedule.wake(at: .seconds(8))

        #expect(schedule.nextTarget == .seconds(10))
    }
}
