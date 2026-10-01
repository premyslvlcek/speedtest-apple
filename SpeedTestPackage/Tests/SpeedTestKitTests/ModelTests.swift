//
//  ModelTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import ICMP
import Testing

@testable import SpeedTestKit

@Suite struct ModelTests {
    @Test func aResultCanBeTakenFromTheLastSample() {
        let sample = ThroughputSample(
            elapsed: .milliseconds(7400),
            totalBytes: 92_500_000,
            currentMbps: 110,
            averageMbps: 100
        )
        let result = TransferResult(lastSample: sample, wasPartial: true)
        #expect(result == TransferResult(
            averageMbps: 100,
            totalBytes: 92_500_000,
            duration: .milliseconds(7400),
            wasPartial: true
        ))
    }

    @Test(arguments: [SpeedTestError.networkChanged, .connectionLost])
    func interruptionsKeepAPartialResult(error: SpeedTestError) {
        #expect(error.isInterruption)
    }

    @Test(arguments: [
        SpeedTestError.offline, .directoryUnavailable, .rateLimited, .noServers, .transferFailed
    ])
    func failuresAreNotInterruptions(error: SpeedTestError) {
        #expect(!error.isInterruption)
    }
}
