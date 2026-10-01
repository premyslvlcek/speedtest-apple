//
//  MeasurementPanel.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import DesignSystem
import SwiftUI

/// Phase label, big number, the four result fields and the inline notes.
struct MeasurementPanel: View {
    let state: SpeedTest.State
    let onOpenSettings: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var bigNumberSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 14) {
            ForEach(state.notes.filter { $0 != .icmpBlocked }, id: \.self) { note in
                NoteView(note: note, onOpenSettings: onOpenSettings)
            }

            header

            ResultCard {
                ResultRow(
                    title: Text(.fieldServer),
                    value: state.serverString,
                    accessibilityIdentifier: "serverField"
                )
                Divider()
                ResultRow(
                    title: Text(.fieldPing),
                    value: state.pingString,
                    accessibilityIdentifier: "pingField"
                )
                Divider()
                ResultRow(
                    title: Text(.fieldDownload),
                    value: state.downloadString,
                    tag: state.downloadTag,
                    accessibilityIdentifier: "downloadField"
                )
                Divider()
                ResultRow(
                    title: Text(.fieldUpload),
                    value: state.uploadString,
                    tag: state.uploadTag,
                    isSecondary: true,
                    accessibilityIdentifier: "uploadField"
                )
            }

            if state.notes.contains(.icmpBlocked) {
                NoteView(note: .icmpBlocked, onOpenSettings: onOpenSettings)
            }

            if let failure = state.failure {
                MessageView(text: failure.message, systemImage: "exclamationmark.triangle", tint: Palette.error)
            }

            if state.showsIntroduction {
                Text(.intro)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(spacing: 2) {
            state.phaseLabel.text
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("phaseLabel")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: SpeedFormat.mbps(state.bigNumber))
                    .font(.system(size: bigNumberSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(.unitMbps)
                    .font(.headline)
                    .foregroundStyle(Palette.secondaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.phaseLabel.text)
            .accessibilityValue(bigNumberAccessibilityValue)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("bigNumber")
        }
    }

    /// Read quietly while it changes 4 times a second; the view announces the final value once.
    private var bigNumberAccessibilityValue: Text {
        guard let value = state.bigNumber else {
            return Text(.accessibilityNoValue)
        }

        return Text(.accessibilityMegabitsPerSecond(SpeedFormat.mbps(value)))
    }
}

private struct NoteView: View {
    let note: SpeedTest.State.Note
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MessageView(text: note.text, systemImage: note.systemImage, tint: Palette.warning)

            if note == .locationOff {
                Button(action: onOpenSettings) {
                    Text(.noteEnableInSettings)
                }
                .buttonStyle(.borderless)
                .font(.footnote.weight(.semibold))
                .padding(.leading, 10)
            }
        }
    }
}

private struct MessageView: View {
    let text: Text
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            text
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(tint)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.12)))
    }
}
