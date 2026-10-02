//
//  SpeedTestView.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import DesignSystem
import HistoryFeature
import SwiftUI

#if os(iOS)
    import UIKit
#endif

@ViewAction(for: SpeedTest.self)
public struct SpeedTestView: View {
    @Bindable public var store: StoreOf<SpeedTest>

    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    public init(store: StoreOf<SpeedTest>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            layout
                .navigationTitle(Text(.appTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        historyButton
                    }
                }
        }
        .sheet(item: $store.scope(\.history, action: \.history)) { historyStore in
            HistoryView(store: historyStore)
        }
        .onChange(of: scenePhase) { _, newValue in
            send(.scenePhaseChanged(newValue))
        }
        .onChange(of: store.phase) { _, newValue in
            announceIfFinished(newValue)
        }
        .sensoryFeedback(.success, trigger: store.phase) { _, newValue in
            newValue == .finished
        }
        #if os(iOS)
        .onChange(of: store.isRunning) { _, isRunning in
            // Keep the screen awake during a test. Not `initial: true`: at launch nothing is running anyway.
            UIApplication.shared.isIdleTimerDisabled = isRunning
        }
        #endif
    }

    /// Two panes on the Mac and on any regular-width iOS screen (iPad, an open iPhone Duo); one column in compact
    /// width. Driven by the size class, not the device, so iPad Split View and the iPhone Duo need no special case.
    @ViewBuilder
    private var layout: some View {
        if usesTwoPanes {
            twoPanes
        } else {
            singleColumn
        }
    }

    private var usesTwoPanes: Bool {
        #if os(macOS)
            true
        #else
            horizontalSizeClass == .regular
        #endif
    }

    /// iPhone: everything in one list, the button pinned at the bottom.
    private var singleColumn: some View {
        List {
            Section {
                measurementPanel
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            uploadSection
            serversSection
        }
        .speedTestListStyle()
        .safeAreaInset(edge: .bottom) {
            startStopButton
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }

    /// Mac and iPad: the measurement and the button on the left, the upload switch and the servers on the right.
    private var twoPanes: some View {
        HStack(spacing: 0) {
            ScrollView {
                measurementPanel
                    .padding(20)
            }
            .frame(minWidth: 340, idealWidth: 400, maxWidth: 520)
            .safeAreaInset(edge: .bottom) {
                startStopButton
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }

            Divider()

            List {
                uploadSection
                serversSection
            }
            .speedTestListStyle()
            .frame(minWidth: 280, idealWidth: 340)
        }
        .background(Palette.screenBackground)
    }

    private var measurementPanel: some View {
        MeasurementPanel(store: store) {
            send(.openSettingsTapped)
        }
    }

    private var uploadSection: some View {
        Section {
            Toggle(isOn: Binding(get: { store.measuresUpload }, set: { send(.uploadToggled($0)) })) {
                Text(.settingsMeasureUpload)
            }
            .disabled(store.isRunning)
            .accessibilityIdentifier("uploadToggle")
        } footer: {
            Text(.settingsMeasureUploadFootnote)
        }
    }

    private var serversSection: some View {
        ServersSection(
            candidates: store.candidates,
            selectedID: store.selection?.server.id,
            isApproximate: store.isApproximate
        )
    }

    private var startStopButton: some View {
        StartStopButton(title: store.buttonTitle) {
            send(store.buttonAction)
        }
    }

    private var historyButton: some View {
        Button {
            send(.historyTapped)
        } label: {
            Label {
                Text(.historyButton)
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
        }
        .accessibilityIdentifier("historyButton")
    }

    private func announceIfFinished(_ phase: SpeedTest.Phase) {
        guard phase == .finished, let average = store.download?.averageMbps else {
            return
        }

        let announcement = String(localized: .accessibilityDownloadAverage(SpeedFormat.mbps(average)))
        AccessibilityNotification.Announcement(announcement).post()
    }
}

private extension View {
    @ViewBuilder
    func speedTestListStyle() -> some View {
        #if os(iOS)
            listStyle(.insetGrouped)
        #else
            listStyle(.inset)
        #endif
    }
}

#Preview("Scripted run") {
    SpeedTestView(store: Store(initialState: SpeedTest.State()) {
        SpeedTest()
    })
}
