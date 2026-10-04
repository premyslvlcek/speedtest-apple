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
                    isPlaceholder: store.serverValue == .choosing,
                    accessibilityIdentifier: "serverField"
                )
                Divider()
                ResultRow(
                    title: Text(.fieldPing),
                    value: store.pingString,
                    spokenValue: store.spokenPing,
                    accessibilityIdentifier: "pingField"
                )
                SpeedRows(store: store)
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

/// The Download row, and the Upload row when upload is measured. Its own view, so a new sample redraws these rows,
/// not the whole panel. Each counts with the big number, so the two never disagree once a count ends.
private struct SpeedRows: View {
    let store: StoreOf<SpeedTest>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Divider()
        downloadRow
        if store.measuresUpload {
            Divider()
            uploadRow
        }
    }

    @ViewBuilder
    private var downloadRow: some View {
        if let value = store.downloadValue {
            ResultRow(
                title: Text(.fieldDownload),
                number: value.mbps,
                format: SpeedTest.State.speedString(mbps:),
                spokenFormat: Self.spoken,
                tag: store.downloadTag,
                accessibilityIdentifier: "downloadField"
            )
            .animation(.counting(reduceMotion: reduceMotion), value: value.mbps)
        } else {
            ResultRow(
                title: Text(.fieldDownload),
                value: store.downloadString,
                accessibilityIdentifier: "downloadField"
            )
        }
    }

    @ViewBuilder
    private var uploadRow: some View {
        if case let .speed(value) = store.uploadValue {
            ResultRow(
                title: Text(.fieldUpload),
                number: value.mbps,
                format: SpeedTest.State.speedString(mbps:),
                spokenFormat: Self.spoken,
                tag: store.uploadTag,
                isSecondary: true,
                accessibilityIdentifier: "uploadField"
            )
            .animation(.counting(reduceMotion: reduceMotion), value: value.mbps)
        } else {
            ResultRow(
                title: Text(.fieldUpload),
                value: store.uploadString,
                isSecondary: true,
                accessibilityIdentifier: "uploadField"
            )
        }
    }

    /// "451 megabits per second", as the big number and the announcements say it.
    private static func spoken(_ mbps: Double) -> String {
        String(localized: .accessibilityMegabitsPerSecond(SpeedFormat.mbps(mbps)))
    }
}

private extension Animation {
    /// Counts to each sample over one sample interval, so the numbers are always moving, never jumping.
    static func counting(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .linear(duration: SpeedTest.configuration.sampleInterval.inSeconds)
    }
}

/// The phase label and the big number. Its own view, so a new sample redraws only this, not the whole panel.
private struct BigNumber: View {
    let store: StoreOf<SpeedTest>

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 64
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .top) {
                // At accessibility sizes a label can take two lines; keeping room for two stops the screen from
                // moving when the phase changes.
                if dynamicTypeSize.isAccessibilitySize {
                    Text(verbatim: "\u{00A0}\n\u{00A0}")
                        .hidden()
                }
                phaseLabel
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(store.phaseLabel.isWarning ? Palette.warning : Palette.secondaryText)
            .multilineTextAlignment(.center)
            // Wraps at large text sizes instead of truncating.
            .fixedSize(horizontal: false, vertical: true)
            // VoiceOver reads it once, as the big number's label.
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                number
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .animation(counting, value: store.bigNumber)

                // No unit without a number, so the dash sits in the middle.
                if store.bigNumber != nil {
                    Text(.unitMbps)
                        .font(.headline)
                        .foregroundStyle(Palette.secondaryText)
                        // At the largest sizes the unit would grow as big as the shrinking number.
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(store.phaseLabel.text)
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("bigNumber")
        }
    }

    private var counting: Animation? {
        .counting(reduceMotion: reduceMotion)
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
                // Light, so the dash doesn't read as a solid bar at this size.
                .fontWeight(.light)
                .foregroundStyle(Palette.secondaryText)
                // While a run works towards its first number (locating, pinging, connecting), a static dash reads
                // as frozen: a spinner in its place, in the same space, so nothing moves when the number arrives.
                .opacity(store.isRunning ? 0 : 1)
                .overlay {
                    if store.isRunning {
                        ProgressView()
                            .controlSize(.large)
                    }
                }
        }
    }

    /// Read quietly while it changes 4 times a second; the view announces the final value once.
    private var accessibilityValue: Text {
        guard let value = store.bigNumber else {
            return Text(.accessibilityNoValue)
        }

        return Text(.accessibilityMegabitsPerSecond(SpeedFormat.mbps(value)))
    }
}

/// The live graph under the big number. Its own view, so a new point redraws only the chart; without a graph an
/// empty space of the same height keeps the card from jumping when a run starts.
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
            .animation(.counting(reduceMotion: reduceMotion), value: series.points)
            // The axis labels stop growing before they crowd out the graph; VoiceOver skips the chart anyway.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        } else {
            Color.clear
                .frame(height: SpeedChart.height)
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
            .fixedSize(horizontal: false, vertical: true)
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
