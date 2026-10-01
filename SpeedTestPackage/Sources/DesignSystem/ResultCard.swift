//
//  ResultCard.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import SwiftUI

/// One grouped card. Put `ResultRow`s in it with `Divider()`s between them.
public struct ResultCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.cardBackground)
        )
    }
}

/// A title on the left, a value on the right, and an optional tag such as "avg".
/// At large Dynamic Type sizes it stacks the value under the title instead of truncating.
public struct ResultRow: View {
    private let title: Text
    private let value: String
    private let tag: String?
    private let isSecondary: Bool
    private let accessibilityIdentifier: String

    public init(
        title: Text,
        value: String,
        tag: String? = nil,
        isSecondary: Bool = false,
        accessibilityIdentifier: String
    ) {
        self.title = title
        self.value = value
        self.tag = tag
        self.isSecondary = isSecondary
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                titleView
                Spacer(minLength: 12)
                valueView
            }

            VStack(alignment: .leading, spacing: 4) {
                titleView
                valueView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var titleView: some View {
        title
            .font(isSecondary ? .subheadline : .body)
            .foregroundStyle(Palette.secondaryText)
    }

    private var valueView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: value)
                .font(isSecondary ? .subheadline : .body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isSecondary ? Palette.secondaryText : Color.primary)
                .multilineTextAlignment(.trailing)

            if let tag {
                Text(verbatim: tag)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.screenBackground))
            }
        }
    }
}

#Preview {
    ResultCard {
        ResultRow(title: Text(verbatim: "Server"), value: "Elektro Solution · Prague",
                  accessibilityIdentifier: "serverField")
        Divider()
        ResultRow(title: Text(verbatim: "Ping"), value: "5 ms", accessibilityIdentifier: "pingField")
        Divider()
        ResultRow(title: Text(verbatim: "Download"), value: "486 Mbps", tag: "avg",
                  accessibilityIdentifier: "downloadField")
        Divider()
        ResultRow(title: Text(verbatim: "Upload"), value: "92 Mbps", tag: "avg", isSecondary: true,
                  accessibilityIdentifier: "uploadField")
    }
    .padding()
    .background(Palette.screenBackground)
}
