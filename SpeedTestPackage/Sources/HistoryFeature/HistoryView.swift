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
                .confirmationDialog($store.scope(\.confirmation, action: \.confirmation))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(entry.serverProvider) · \(entry.serverCity)")
                    .font(.headline)
                Spacer()
                Text(entry.date, format: .dateTime.day().month().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                speed(entry.downloadMbps, systemImage: "arrow.down")
                    .accessibilityLabel(Text(.historyDownloadAccessibility(SpeedFormat.mbps(entry.downloadMbps))))
                if let upload = entry.uploadMbps {
                    speed(upload, systemImage: "arrow.up")
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

    private func speed(_ mbps: Double, systemImage: String) -> some View {
        Label {
            Text(.historySpeed(SpeedFormat.mbps(mbps)))
        } icon: {
            Image(systemName: systemImage)
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
