//
//  StopwatchTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Clocks
import Testing
import TestSupport

@testable import SpeedTestKit

@Suite(.mainSerialExecutor) struct StopwatchTests {
    @Test func measuresOnTheInjectedClock() async {
        let clock = TestClock()
        let stopwatch = Stopwatch(clock: clock)

        await clock.advance(by: .milliseconds(250))
        #expect(stopwatch.elapsed() == .milliseconds(250))

        await clock.advance(by: .seconds(15))
        #expect(stopwatch.elapsed() == .milliseconds(15250))
    }
}
