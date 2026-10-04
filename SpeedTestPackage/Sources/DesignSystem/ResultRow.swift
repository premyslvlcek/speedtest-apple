//
//  ResultRow.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 04.10.2026.
//

import SwiftUI

/// A short label after a value, such as "avg", and what VoiceOver reads for it ("average").
public struct ResultTag: Equatable, Sendable {
    public let text: String
    public let spokenText: String

    public init(text: String, spokenText: String) {
        self.text = text
        self.spokenText = spokenText
    }
}

/// A title on the left, a value on the right, and an optional tag such as "avg".
/// At accessibility text sizes it stacks the value under the title and the tag under the value. The value wraps
/// rather than truncates.
public struct ResultRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: Text
    private let value: Value
    private let tag: ResultTag?
    /// What VoiceOver reads instead of the value, when the two differ ("3 of 5 replies" for "3/5").
    private let spokenValue: String?
    /// A value that stands in for one still to come ("—", "choosing…"), in the secondary color.
    private let isPlaceholder: Bool
    private let isSecondary: Bool
    private let accessibilityIdentifier: String

    public init(
        title: Text,
        value: String,
        tag: ResultTag? = nil,
        spokenValue: String? = nil,
        isPlaceholder: Bool = false,
        isSecondary: Bool = false,
        accessibilityIdentifier: String
    ) {
        self.init(
            title: title,
            value: .text(value),
            tag: tag,
            spokenValue: spokenValue,
            isPlaceholder: isPlaceholder || value == SpeedFormat.placeholder,
            isSecondary: isSecondary,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    /// A number that counts to each new value, like `AnimatedNumber`, inside the animation the caller sets on the
    /// row. `format` turns it into the text shown, every frame; VoiceOver reads the final value through
    /// `spokenFormat`.
    public init(
        title: Text,
        number: Double,
        format: @escaping (Double) -> String,
        spokenFormat: (Double) -> String,
        tag: ResultTag? = nil,
        isSecondary: Bool = false,
        accessibilityIdentifier: String
    ) {
        self.init(
            title: title,
            value: .number(number, format: format),
            tag: tag,
            spokenValue: spokenFormat(number),
            isPlaceholder: false,
            isSecondary: isSecondary,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    private init(
        title: Text,
        value: Value,
        tag: ResultTag?,
        spokenValue: String?,
        isPlaceholder: Bool,
        isSecondary: Bool,
        accessibilityIdentifier: String
    ) {
        self.title = title
        self.value = value
        self.tag = tag
        self.spokenValue = spokenValue
        self.isPlaceholder = isPlaceholder
        self.isSecondary = isSecondary
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        Group {
            if isStacked {
                VStack(alignment: .leading, spacing: 4) {
                    titleView
                    valueView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    titleView
                        .layoutPriority(1)
                    Spacer(minLength: 12)
                    valueView
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var isStacked: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var titleView: some View {
        title
            .font(isSecondary ? .subheadline : .body)
            .foregroundStyle(Palette.secondaryText)
    }

    private var valueView: some View {
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return layout {
            valueText
                .font(isSecondary ? .subheadline : .body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .multilineTextAlignment(isStacked ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: spokenValue ?? value.finalText))

            if let tag {
                Text(verbatim: tag.text)
                    // It says what the number is, so it's readable: primary text, not the secondary grey.
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.screenBackground))
                    .accessibilityLabel(Text(verbatim: tag.spokenText))
            }
        }
    }

    @ViewBuilder
    private var valueText: some View {
        switch value {
        case let .number(number, format):
            AnimatedNumber(number) { Text(verbatim: format($0)) }

        case let .text(text):
            Text(verbatim: text)
        }
    }

    /// A placeholder is quiet; a value isn't.
    private var valueColor: Color {
        isSecondary || isPlaceholder ? Palette.secondaryText : Color.primary
    }
}

private extension ResultRow {
    enum Value {
        case text(String)
        case number(Double, format: (Double) -> String)

        /// The value as it reads once any count has finished.
        var finalText: String {
            switch self {
            case let .number(number, format):
                format(number)

            case let .text(text):
                text
            }
        }
    }
}
