//
//  PathSnapshotTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Testing

@testable import SpeedTestKit

@Suite struct PathSnapshotTests {
    private static let wifi = PathSnapshot(isSatisfied: true, primaryInterface: .wifi)
    private static let cellular = PathSnapshot(isSatisfied: true, primaryInterface: .cellular)

    /// A secondary interface appearing, or a flag flipping, looks exactly like "unchanged" here: only the primary
    /// interface and whether the path is usable are modelled.
    @Test func anUnchangedPathIsNoInterruption() {
        #expect(!PathSnapshot.isInterruption(baseline: Self.wifi, current: Self.wifi))
    }

    /// Wi-Fi dropped and mobile data took over: the rest of the transfer would measure another network.
    @Test func anotherPrimaryInterfaceIsAnInterruption() {
        #expect(PathSnapshot.isInterruption(baseline: Self.wifi, current: Self.cellular))
    }

    @Test func anUnusablePathIsAnInterruptionEvenWithTheSameInterface() {
        let stillWifiButDown = PathSnapshot(isSatisfied: false, primaryInterface: .wifi)

        #expect(PathSnapshot.isInterruption(baseline: Self.wifi, current: stillWifiButDown))
    }
}
