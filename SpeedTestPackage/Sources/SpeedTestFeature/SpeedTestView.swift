//
//  SpeedTestView.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import DesignSystem
import SwiftUI

#if os(iOS)
    import UIKit
#endif

@ViewAction(for: SpeedTest.self)
public struct SpeedTestView: View {
    @Bindable public var store: StoreOf<SpeedTest>

    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<SpeedTest>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section {
                MeasurementPanel(store: store) {
                    send(.openSettingsTapped)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Toggle(isOn: Binding(get: { store.measuresUpload }, set: { send(.uploadToggled($0)) })) {
                    Text(.settingsMeasureUpload)
                }
                .disabled(store.isRunning)
                .accessibilityIdentifier("uploadToggle")
            } footer: {
                Text(.settingsMeasureUploadFootnote)
            }

            ServersSection(
                candidates: store.candidates,
                selectedID: store.selection?.server.id,
                isApproximate: store.isApproximate
            )
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .safeAreaInset(edge: .bottom) {
            StartStopButton(title: store.buttonTitle, action: buttonTapped)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
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
            // Keep the screen awake during a test. Not `initial: true`: the view is rendered in
            // snapshot tests, which have no UIApplication, and at launch nothing is running anyway.
            UIApplication.shared.isIdleTimerDisabled = isRunning
        }
        #endif
    }

    private func buttonTapped() {
        if store.buttonTitle == .tryAgain {
            send(.retryTapped)
        } else {
            send(.startStopTapped)
        }
    }

    private func announceIfFinished(_ phase: SpeedTest.Phase) {
        guard phase == .finished, let average = store.download?.averageMbps else {
            return
        }

        let announcement = String(localized: .accessibilityDownloadAverage(SpeedFormat.mbps(average)))
        AccessibilityNotification.Announcement(announcement).post()
    }
}

#Preview("Scripted run") {
    SpeedTestView(store: Store(initialState: SpeedTest.State()) {
        SpeedTest()
    })
}
