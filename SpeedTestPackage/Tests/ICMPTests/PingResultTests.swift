//
//  PingResultTests.swift
//  ICMPTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ICMP
import Testing

@Suite struct PingResultTests {
    @Test func medianOfAnOddCountIsTheMiddleValue() {
        let result = PingResult(rtts: [.milliseconds(9), .milliseconds(5), .milliseconds(7)], sent: 5)

        #expect(result.median == .milliseconds(7))
    }

    @Test func medianOfAnEvenCountIsTheMeanOfTheMiddleTwo() {
        let result = PingResult(
            rtts: [.milliseconds(8), .milliseconds(4), .milliseconds(6), .milliseconds(10)],
            sent: 5
        )

        #expect(result.median == .milliseconds(7))
    }

    @Test func noReplyHasNoMedianAndIsUnreachable() {
        let result = PingResult.noReply(sent: 5)

        #expect(result.median == nil)
    }
}
