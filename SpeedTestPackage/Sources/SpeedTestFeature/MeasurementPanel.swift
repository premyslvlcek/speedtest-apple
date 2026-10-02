//
//  MeasurementPanel.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import DesignSystem
import SpeedTestKit
import SwiftUI

/// Phase label, big number, the four result fields and the inline notes.
struct MeasurementPanel: View {
    /// Read through the store, not a copy of its state: every value read here is observed, so each new sample
    /// redraws the live number and the elapsed time.
    let store: StoreOf<SpeedTest>
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(store.notes.filter { $0 != .icmpBlocked }, id: \.self) { note in
                NoteView(note: note, onOpenSettings: onOpenSettings)
            }

            BigNumber(store: store)

            LiveChart(store: store)

            ResultCard {
                ResultRow(
                    title: Text(.fieldServer),
                    value: store.serverString,
                    accessibilityIdentifier: "serverField"
                )
                Divider()
                ResultRow(
                    title: Text(.fieldPing),
                    value: store.pingString,
                    accessibilityIdentifier: "pingField"
                )
                Divider()
                ResultRow(
                    title: Text(.fieldDownload),
                    value: store.downloadString,
                    tag: store.downloadTag,
                    accessibilityIdentifier: "downloadField"
                )
                if store.measuresUpload {
                    Divider()
                    ResultRow(
                        title: Text(.fieldUpload),
                        value: store.uploadString,
                        tag: store.uploadTag,
                        isSecondary: true,
                        accessibilityIdentifier: "uploadField"
                    )
                }
            }

            if let clientIP = store.clientIP {
                ClientIPLine(clientIP: clientIP)
            }

            if store.notes.contains(.icmpBlocked) {
                NoteView(note: .icmpBlocked, onOpenSettings: onOpenSettings)
            }

            if let failure = store.failure {
                MessageView(text: failure.message, systemImage: "exclamationmark.triangle", tint: Palette.error)
            }

            if store.showsIntroduction {
                Text(.intro)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The phase label and the big number. Its own view, so a new sample redraws only this, not the whole panel.
private struct BigNumber: View {
    let store: StoreOf<SpeedTest>

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 64
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 2) {
            phaseLabel
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("phaseLabel")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                number
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .animation(counting, value: store.bigNumber)

                Text(.unitMbps)
                    .font(.headline)
                    .foregroundStyle(Palette.secondaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.phaseLabel.text)
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("bigNumber")
        }
    }

    /// Counts to each sample over one sample interval, so the numbers are always moving, never jumping.
    private var counting: Animation? {
        reduceMotion ? nil : .linear(duration: Self.interval)
    }

    /// The elapsed time in the label counts too: 0.3, 0.4, 0.5 s instead of 0.3, 0.5, 0.8.
    @ViewBuilder
    private var phaseLabel: some View {
        let label = store.phaseLabel
        if let seconds = label.seconds {
            AnimatedNumber(seconds) { label.withSeconds($0).text }
                .animation(counting, value: seconds)
        } else {
            label.text
        }
    }

    @ViewBuilder
    private var number: some View {
        if let value = store.bigNumber {
            AnimatedNumber(value) { Text(verbatim: SpeedFormat.mbps($0)) }
        } else {
            Text(verbatim: SpeedFormat.placeholder)
        }
    }

    /// Read quietly while it changes 4 times a second; the view announces the final value once.
    private var accessibilityValue: Text {
        guard let value = store.bigNumber else {
            return Text(.accessibilityNoValue)
        }

        return Text(.accessibilityMegabitsPerSecond(SpeedFormat.mbps(value)))
    }

    private static let interval = SpeedTest.configuration.sampleInterval.inSeconds
}

/// The live graph under the big number. Its own view, so a new point redraws only the chart; before the first
/// transfer of a run an empty space of the same height keeps the card from jumping.
private struct LiveChart: View {
    let store: StoreOf<SpeedTest>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let series = store.chartSeries {
            SpeedChart(
                points: series.points,
                average: series.average,
                duration: series.duration,
                tint: series.direction == .download ? Palette.download : Palette.upload
            )
            // New points slide in over one sample interval, like the numbers above.
            .animation(
                reduceMotion ? nil : .linear(duration: SpeedTest.configuration.sampleInterval.inSeconds),
                value: series.points
            )
        } else if store.isRunning {
            Color.clear
                .frame(height: 120)
        }
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

/// The public address the run started from, quietly under the card.
private struct ClientIPLine: View {
    let clientIP: ClientIP

    var body: some View {
        text
            .font(.footnote)
            .foregroundStyle(Palette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .accessibilityIdentifier("ipField")
    }

    private var text: Text {
        if let provider = clientIP.provider {
            Text(.ipAddressWithProvider(clientIP.address, provider))
        } else {
            Text(.ipAddress(clientIP.address))
        }
    }
}
