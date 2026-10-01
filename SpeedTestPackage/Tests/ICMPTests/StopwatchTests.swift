//
//  StopwatchTests.swift
//  ICMPTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Clocks
@testable import ICMP
import Testing

@Suite struct StopwatchTests {
    @Test func measuresElapsedTimeOnTheGivenClock() async {
        let clock = TestClock()
        let stopwatch = Stopwatch(clock: clock)

        await clock.advance(by: .milliseconds(250))

        #expect(stopwatch.elapsed() == .milliseconds(250))
    }
}
