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
/// A `Section`, so it sits in a `List` next to the history.
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

private struct ServerRow: View {
    let candidate: Candidate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(Palette.download)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: candidate.server.name)
                    .lineLimit(2)

                let distance = SpeedFormat.distance(meters: candidate.distance)
                if !distance.isEmpty {
                    Text(verbatim: distance)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                }
            }

            Spacer(minLength: 8)

            ping
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var ping: some View {
        switch candidate.ping {
        case let .finished(result):
            Text(verbatim: SpeedFormat.pingSummary(
                milliseconds: result.median?.inMilliseconds,
                received: result.received,
                sent: result.sent
            ))
            .monospacedDigit()
            .foregroundStyle(result.isReachable ? Palette.success : Palette.secondaryText)

        case .pending:
            ProgressView()
                .controlSize(.small)
        }
    }
}
