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

#Preview {
    ResultCard {
        ResultRow(title: Text(verbatim: "Server"), value: "Elektro Solution · Prague",
                  accessibilityIdentifier: "serverField")
        Divider()
        ResultRow(title: Text(verbatim: "Ping"), value: "5 ms", accessibilityIdentifier: "pingField")
        Divider()
        ResultRow(title: Text(verbatim: "Download"), value: "486 Mbps",
                  tag: ResultTag(text: "avg", spokenText: "average"), accessibilityIdentifier: "downloadField")
        Divider()
        ResultRow(title: Text(verbatim: "Upload"), value: "92 Mbps",
                  tag: ResultTag(text: "avg", spokenText: "average"), isSecondary: true,
                  accessibilityIdentifier: "uploadField")
    }
    .padding()
    .background(Palette.screenBackground)
}
