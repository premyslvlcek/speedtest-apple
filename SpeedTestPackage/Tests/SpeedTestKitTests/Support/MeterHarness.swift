//
//  MeterHarness.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Clocks
import Dependencies
import SpeedTestKit

/// The live `TransferMeter` on fakes. With the defaults every transfer starts at once and runs to the end.
func makeMeter(
    transfer: TransferService = FakeTransferService().service,
    network: NetworkMonitor = FakeNetworkMonitor().monitor,
    clock: any Clock<Duration> = ImmediateClock()
) -> TransferMeter {
    withDependencies {
        $0.transferService = transfer
        $0.networkMonitor = network
        $0.continuousClock = clock
    } operation: {
        TransferMeter.live
    }
}

enum MeterFixtures {
    static let server = Server.fixture("vinohrady")
    static let token = TransferToken(value: "token-1", ttl: .seconds(80))
}

/// Everything one measurement produced.
struct Measurement {
    var samples: [ThroughputSample] = []
    var error: (any Error)?

    var speedTestError: SpeedTestError? {
        error as? SpeedTestError
    }
}

extension AsyncThrowingStream where Element == ThroughputSample, Failure == any Error {
    /// Reads the stream to its end, in the calling task.
    func collect() async -> Measurement {
        var measurement = Measurement()
        do {
            for try await sample in self {
                measurement.samples.append(sample)
            }
        } catch {
            measurement.error = error
        }
        return measurement
    }
}
