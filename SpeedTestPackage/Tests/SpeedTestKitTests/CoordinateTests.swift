//
//  CoordinateTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import Testing

@testable import SpeedTestKit

@Suite struct CoordinateTests {
    static let prague = Coordinate(latitude: 50.0755, longitude: 14.4378)
    static let brno = Coordinate(latitude: 49.1951, longitude: 16.6068)

    @Test func pragueToBrnoIs184Kilometres() {
        // Reference value computed independently with the same formula and the mean Earth radius: 184 332.5 m.
        // Within a metre, so a wrong radius (the equatorial one is 206 m off here) fails the test.
        #expect(abs(Self.prague.distance(to: Self.brno) - 184_332.5) < 1)
    }
}
