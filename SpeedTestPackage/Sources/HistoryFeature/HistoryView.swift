//
//  HistoryView.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import ComposableArchitecture
import DesignSystem
import SwiftUI

/// The list of past results, shown in a sheet.
@ViewAction(for: History.self)
public struct HistoryView: View {
    @Bindable public var store: StoreOf<History>

    public init(store: StoreOf<History>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(store.entries) { entry in
                    HistoryRow(entry: entry)
                }
                .onDelete { send(.deleteTapped($0)) }
            }
            .overlay {
                if store.entries.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text(.historyEmptyTitle)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    } description: {
                        Text(.historyEmptyMessage)
                    }
                }
            }
            .navigationTitle(Text(.historyTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            send(.doneTapped)
                        } label: {
                            Text(.historyDone)
                        }
                    }
                    ToolbarItem(placement: Self.clearPlacement) {
                        Button(role: .destructive) {
                            send(.clearTapped)
                        } label: {
                            Text(.historyClear)
                        }
                        .disabled(store.entries.isEmpty)
                    }
                }
                .alert($store.scope(\.alert, action: \.alert))
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 420)
        #endif
    }
}

extension HistoryView {
    /// Opposite Done, as the HIG asks: the leading side of the navigation bar on iOS. On the Mac a sheet's
    /// toolbar sits at the bottom, where the destructive placement puts it on the left.
    private static var clearPlacement: ToolbarItemPlacement {
        #if os(iOS)
            .topBarLeading
        #else
            .destructiveAction
        #endif
    }
}

/// One result: where and when, the speeds and the ping, and the address the test ran from.
struct HistoryRow: View {
    let entry: HistoryEntry
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // At accessibility text sizes everything stacks: side by side, the date and the numbers break apart.
            header {
                Text(verbatim: "\(entry.serverProvider)\u{00A0}· \(entry.serverCity)")
                    .font(.headline)
                if !isStacked {
                    Spacer()
                }
                Text(entry.date, format: .dateTime.day().month().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            values {
                speed(entry.downloadMbps, systemImage: "arrow.down", tint: Palette.download)
                    .accessibilityLabel(Text(.historyDownloadAccessibility(SpeedFormat.mbps(entry.downloadMbps))))
                if let upload = entry.uploadMbps {
                    speed(upload, systemImage: "arrow.up", tint: Palette.upload)
                        .accessibilityLabel(Text(.historyUploadAccessibility(SpeedFormat.mbps(upload))))
                }
                Text(verbatim: SpeedFormat.ping(milliseconds: entry.pingMilliseconds))
                    .foregroundStyle(.secondary)
            }
            .font(.body.monospacedDigit())
            if let address = entry.ipAddress {
                ipText(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("historyRow")
    }

    private var isStacked: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var header: AnyLayout {
        isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
    }

    private var values: AnyLayout {
        isStacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 16))
    }

    /// The speed with an arrow in the direction's color.
    private func speed(_ mbps: Double, systemImage: String, tint: Color) -> some View {
        Label {
            Text(.historySpeed(SpeedFormat.mbps(mbps)))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }

    private func ipText(_ address: String) -> Text {
        if let provider = entry.ipProvider {
            Text(.historyIpWithProvider(address, provider))
        } else {
            Text(.historyIp(address))
        }
    }
}
