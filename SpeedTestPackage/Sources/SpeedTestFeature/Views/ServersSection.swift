//
//  ServersSection.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import DesignSystem
import ICMP
import SpeedTestKit
import SwiftUI

/// "Closest servers", filling in live as each ICMP result arrives. The visible proof of real ICMP.
/// A `Section`, so it sits in a `List` under the upload switch.
struct ServersSection: View {
    let candidates: IdentifiedArrayOf<Candidate>
    let selectedID: Server.ID?
    let isApproximate: Bool

    var body: some View {
        if !candidates.isEmpty {
            Section {
                ForEach(candidates) { candidate in
                    ServerRow(candidate: candidate, isSelected: candidate.id == selectedID)
                }
            } header: {
                isApproximate
                    ? Text(.serversByIP)
                    : Text(.serversClosest)
            }
        }
    }
}

/// The name and distance on the left and the ping on the right; at accessibility text sizes the ping goes under
/// the name, which then wraps in full.
private struct ServerRow: View {
    let candidate: Candidate
    let isSelected: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: isStacked ? .firstTextBaseline : .center, spacing: 8) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Palette.download)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)

            if isStacked {
                VStack(alignment: .leading, spacing: 2) {
                    details
                    ping
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                details

                Spacer(minLength: 8)

                ping
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var isStacked: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: candidate.server.name)
                .lineLimit(isStacked ? nil : 2)
                .fixedSize(horizontal: false, vertical: isStacked)

            let distance = SpeedFormat.distance(meters: candidate.distance)
            if !distance.isEmpty {
                Text(verbatim: distance)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var ping: some View {
        switch candidate.ping {
        case let .finished(result):
            Text(verbatim: result.summary)
                .monospacedDigit()
                .accessibilityLabel(Text(verbatim: result.spokenSummary))
                .foregroundStyle(result.isReachable ? Palette.success : Palette.secondaryText)

        case .pending:
            ProgressView()
                .controlSize(.small)
        }
    }
}
