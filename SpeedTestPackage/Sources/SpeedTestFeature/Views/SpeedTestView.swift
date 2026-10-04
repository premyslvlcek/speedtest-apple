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
struct SpeedTestView: View {
    @Bindable var store: StoreOf<SpeedTest>

    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    #if os(macOS)
        /// Held while a test runs, so App Nap doesn't delay the sample timer of a hidden window.
        @State private var activity: (any NSObjectProtocol)?
    #endif

    var body: some View {
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
        .onChange(of: store.phase) {
            announce()
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
        #if os(macOS)
        .onChange(of: store.isRunning) { _, isRunning in
            if isRunning {
                activity = ProcessInfo.processInfo.beginActivity(
                    options: .userInitiatedAllowingIdleSystemSleep,
                    reason: "Speed test"
                )
            } else if let activity {
                ProcessInfo.processInfo.endActivity(activity)
                self.activity = nil
            }
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

    /// Compact width: everything in one list, the button pinned at the bottom.
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

    /// Regular width, and always on the Mac: the measurement and the button on the left, the upload switch and the servers on the right.
    /// The measurement is the brief's screen, so its pane takes the space; the servers pane stays narrow.
    private var twoPanes: some View {
        HStack(spacing: 0) {
            ScrollView {
                measurementPanel
                    .frame(maxWidth: 560)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            .frame(minWidth: 340, maxWidth: .infinity)
            .layoutPriority(1)
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
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 320)
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

    /// Once per ended run: the result, the reason it stopped, or the error (`announcement`).
    private func announce() {
        guard let announcement = store.announcement else {
            return
        }

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
