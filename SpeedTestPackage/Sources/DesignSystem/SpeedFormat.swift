//
//  SpeedFormat.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// Display strings for the numbers on screen. Numbers follow the user's locale (decimal separator, grouping,
/// digits); the units are SI symbols ("ms", "s", "km"), joined to the number by a non-breaking space so the two
/// never land on different lines.
public enum SpeedFormat {
    public static let placeholder = "—"

    /// Decimal megabits. Values that round to 100 or more are whole numbers; smaller ones get one decimal.
    public static func mbps(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite, value >= 0 else {
            return placeholder
        }

        let fractionDigits = (value * 10).rounded() / 10 >= 100 ? 0 : 1
        return value.formatted(number(fractionDigits, locale))
    }

    /// Whole milliseconds; anything below 1 ms reads "<1 ms".
    public static func ping(milliseconds: Double?, locale: Locale = .current) -> String {
        guard let milliseconds, milliseconds.isFinite, milliseconds >= 0 else {
            return placeholder
        }

        if milliseconds < 1 {
            return "<1\u{00A0}ms"
        }

        return "\(milliseconds.formatted(number(0, locale)))\u{00A0}ms"
    }

    /// "6 ms" when every request came back, "6 ms · 3/5" with loss, "no reply" when none did.
    public static func pingSummary(
        milliseconds: Double?,
        received: Int,
        sent: Int,
        locale: Locale = .current
    ) -> String {
        guard received > 0 else {
            return noReply(locale: locale)
        }

        let value = ping(milliseconds: milliseconds, locale: locale)
        guard received < sent else {
            return value
        }

        return "\(value) · \(received)/\(sent)"
    }

    /// A ping that got no reply at all.
    public static func noReply(locale: Locale = .current) -> String {
        var noReply = LocalizedStringResource.pingNoReply
        noReply.locale = locale
        return String(localized: noReply)
    }

    /// What VoiceOver reads for `pingSummary`: "6 ms, 3 of 5 replies" rather than a fraction. Without loss, the
    /// same as shown.
    public static func spokenPingSummary(
        milliseconds: Double?,
        received: Int,
        sent: Int,
        locale: Locale = .current
    ) -> String {
        guard received > 0, received < sent else {
            return pingSummary(milliseconds: milliseconds, received: received, sent: sent, locale: locale)
        }

        let value = ping(milliseconds: milliseconds, locale: locale)
        var spoken = LocalizedStringResource.pingSpokenReplies(value, received, sent)
        spoken.locale = locale
        return String(localized: spoken)
    }

    /// Seconds with one decimal: "7.4 s".
    public static func elapsed(seconds: Double, locale: Locale = .current) -> String {
        "\(max(0, seconds).formatted(number(1, locale)))\u{00A0}s"
    }

    /// Kilometres: one decimal below 10 km, whole above. Empty when there is no distance (approximate mode).
    public static func distance(meters: Double?, locale: Locale = .current) -> String {
        guard let meters, meters.isFinite, meters >= 0 else {
            return ""
        }

        let kilometers = meters / 1000
        let tenths = (kilometers * 10).rounded() / 10
        if tenths < 0.1 {
            return "<\(0.1.formatted(number(1, locale)))\u{00A0}km"
        }

        let fractionDigits = tenths < 10 ? 1 : 0
        return "\(kilometers.formatted(number(fractionDigits, locale)))\u{00A0}km"
    }

    /// A locale-aware number with a fixed number of decimals, rounded half away from zero (486.5 → 487), not
    /// half to even as the default would.
    private static func number(_ fractionDigits: Int, _ locale: Locale) -> FloatingPointFormatStyle<Double> {
        .number
            .precision(.fractionLength(fractionDigits))
            .rounded(rule: .toNearestOrAwayFromZero)
            .locale(locale)
    }
}
