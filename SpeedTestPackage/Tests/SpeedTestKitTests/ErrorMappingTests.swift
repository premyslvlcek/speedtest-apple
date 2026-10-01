//
//  ErrorMappingTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import Testing

@testable import SpeedTestKit

@Suite struct ErrorMappingTests {
    @Test(arguments: [
        URLError(.notConnectedToInternet),
        URLError(.dataNotAllowed),
        URLError(.internationalRoamingOff)
    ])
    func aDeviceWithoutANetworkIsOfflineEverywhere(error: URLError) {
        #expect(SpeedTestError.mapping(error) == .offline)
        #expect(SpeedTestError.directoryMapping(error) == .offline)
    }

    @Test func aDroppedConnectionIsOfflineOnlyForTheDirectory() {
        // The directory is one request: if its connection drops, the network is the likely cause. During a run
        // a dropped connection is often the test server's doing, so it's a transfer failure and failover applies.
        let dropped = URLError(.networkConnectionLost)

        #expect(SpeedTestError.directoryMapping(dropped) == .offline)
        #expect(SpeedTestError.mapping(dropped) == .transferFailed)
    }

    @Test func cancellationEndsTheRunQuietly() {
        #expect(SpeedTestError.mapping(CancellationError()) == nil)
        #expect(SpeedTestError.mapping(URLError(.cancelled)) == nil)
        #expect(SpeedTestError.directoryMapping(CancellationError()) == nil)
        #expect(SpeedTestError.directoryMapping(URLError(.cancelled)) == nil)
    }

    @Test func aSpeedTestErrorPassesThroughUnchanged() {
        // Neither function's fallback, so only the pass-through can produce it.
        #expect(SpeedTestError.mapping(SpeedTestError.connectionLost) == .connectionLost)
        #expect(SpeedTestError.directoryMapping(SpeedTestError.connectionLost) == .connectionLost)
    }

    @Test func anythingElseThatEndsATransferIsATransferFailure() {
        let errors: [any Error] = [
            URLError(.timedOut),
            // During a run a 429 is a failed connection (failover applies), unlike for the directory.
            HTTPStatusError(statusCode: 429)
        ]
        for error in errors {
            #expect(SpeedTestError.mapping(error) == .transferFailed, "\(error)")
        }
    }

    @Test func aDirectory429IsRateLimited() {
        #expect(SpeedTestError.directoryMapping(HTTPStatusError(statusCode: 429)) == .rateLimited)
    }

    @Test func anyOtherDirectoryFailureMeansTheDirectoryIsUnavailable() {
        let errors: [any Error] = [
            URLError(.timedOut),
            URLError(.cannotConnectToHost),
            URLError(.cannotFindHost),
            HTTPStatusError(statusCode: 401),
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "not JSON"))
        ]
        for error in errors {
            #expect(SpeedTestError.directoryMapping(error) == .directoryUnavailable, "\(error)")
        }
    }
}
