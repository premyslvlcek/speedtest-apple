//
//  SpeedFormatTests.swift
//  DesignSystemTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import Testing

@testable import DesignSystem

/// One case per path: each way a value is rejected, each display branch, and the rounding boundaries.
@Suite struct SpeedFormatTests {
    /// The tests pin a locale, so they don't depend on the machine's region.
    static let english = Locale(identifier: "en_US")

    static let mbpsCases: [(Double, String)] = [
        (-1, "—"),
        (.nan, "—"),
        (12.35, "12.4"),
        // Rounds to 100.0 at one decimal, so it's shown as a whole number although the value is below 100.
        (99.96, "100"),
        (486.5, "487")
    ]

    @Test(arguments: mbpsCases)
    func mbps(value: Double, expected: String) {
        #expect(SpeedFormat.mbps(value, locale: Self.english) == expected)
    }

    static let pingCases: [(Double?, String)] = [
        (nil, "—"),
        (-3, "—"),
        (0.4, "<1\u{00A0}ms"),
        (1, "1\u{00A0}ms"),
        (5.6, "6\u{00A0}ms")
    ]

    @Test(arguments: pingCases)
    func ping(milliseconds: Double?, expected: String) {
        #expect(SpeedFormat.ping(milliseconds: milliseconds, locale: Self.english) == expected)
    }

    @Test func pingSummaryWithEveryReply() {
        #expect(SpeedFormat.pingSummary(milliseconds: 5.8, received: 5, sent: 5, locale: Self.english) == "6\u{00A0}ms")
    }

    @Test func pingSummaryShowsLoss() {
        let summary = SpeedFormat.pingSummary(milliseconds: 5.8, received: 3, sent: 5, locale: Self.english)
        #expect(summary == "6\u{00A0}ms · 3/5")
    }

    /// VoiceOver hears "3 of 5 replies", not a fraction. Without loss it hears what is shown.
    @Test func spokenPingSummarySaysHowManyReplied() {
        #expect(SpeedFormat.spokenPingSummary(milliseconds: 5.8, received: 3, sent: 5, locale: Self.english)
            == "6\u{00A0}ms, 3 of 5 replies")
        #expect(SpeedFormat.spokenPingSummary(milliseconds: 5.8, received: 5, sent: 5, locale: Self.english)
            == "6\u{00A0}ms")
    }

    @Test func pingSummaryWithNoReply() {
        #expect(SpeedFormat.pingSummary(milliseconds: nil, received: 0, sent: 5, locale: Self.english) == "no reply")
    }

    static let elapsedCases: [(Double, String)] = [
        (-0.2, "0.0\u{00A0}s"),
        (7.45, "7.5\u{00A0}s")
    ]

    @Test(arguments: elapsedCases)
    func elapsed(seconds: Double, expected: String) {
        #expect(SpeedFormat.elapsed(seconds: seconds, locale: Self.english) == expected)
    }

    static let distanceCases: [(Double?, String)] = [
        (nil, ""),
        (-5, ""),
        (40, "<0.1\u{00A0}km"),
        (400, "0.4\u{00A0}km"),
        // Rounds to 10.0 km at one decimal, so it's shown whole.
        (9960, "10\u{00A0}km")
    ]

    @Test(arguments: distanceCases)
    func distance(meters: Double?, expected: String) {
        #expect(SpeedFormat.distance(meters: meters, locale: Self.english) == expected)
    }

    @Test func numbersFollowTheLocale() {
        let czech = Locale(identifier: "cs_CZ")

        #expect(SpeedFormat.mbps(12.35, locale: czech) == "12,4")
        #expect(SpeedFormat.distance(meters: 400, locale: czech) == "0,4\u{00A0}km")
    }

    @Test func noReplyIsTranslated() {
        let czech = Locale(identifier: "cs_CZ")

        #expect(SpeedFormat.pingSummary(milliseconds: nil, received: 0, sent: 5, locale: czech) == "bez odpovědi")
    }
}
