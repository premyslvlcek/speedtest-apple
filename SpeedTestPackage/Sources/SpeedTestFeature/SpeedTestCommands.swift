//
//  SpeedTestCommands.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

#if os(macOS)
    import ComposableArchitecture
    import SwiftUI

    /// The Mac's Test menu: Start/Stop on ⌘R, and the history on ⌘Y.
    struct SpeedTestCommands: Commands {
        let store: StoreOf<SpeedTest>

        var body: some Commands {
            CommandMenu(Text(.menuTest)) {
                StartStopMenuItem(store: store)
                Button {
                    store.send(.view(.historyTapped))
                } label: {
                    Text(.menuHistory)
                }
                .keyboardShortcut("y", modifiers: .command)
            }
        }
    }

    /// A view, so its title follows the store through observation.
    private struct StartStopMenuItem: View {
        let store: StoreOf<SpeedTest>

        var body: some View {
            Button {
                store.send(.view(store.buttonAction))
            } label: {
                store.isRunning ? Text(.menuStopTest) : Text(.menuStartTest)
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
#endif
