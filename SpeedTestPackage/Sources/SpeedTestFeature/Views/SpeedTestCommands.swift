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
                HistoryMenuItem(store: store)
            }
        }
    }

    /// A view, so it's enabled and disabled as the sheet opens and closes, through observation.
    @ViewAction(for: SpeedTest.self)
    private struct HistoryMenuItem: View {
        let store: StoreOf<SpeedTest>

        var body: some View {
            Button {
                send(.historyTapped)
            } label: {
                Text(.menuHistory)
            }
            .keyboardShortcut("y", modifiers: .command)
            .disabled(store.history != nil)
        }
    }

    /// A view, so its title follows the store through observation.
    @ViewAction(for: SpeedTest.self)
    private struct StartStopMenuItem: View {
        let store: StoreOf<SpeedTest>

        var body: some View {
            Button {
                send(store.buttonAction)
            } label: {
                title
            }
            .keyboardShortcut("r", modifiers: .command)
            // The sheet covers the window: a run started behind it would be out of sight. Stop still works.
            .disabled(store.history != nil && !store.isRunning)
        }

        /// The button's title, as a menu item.
        private var title: Text {
            switch store.buttonTitle {
            case .runAgain:
                Text(.menuRunAgain)

            case .start:
                Text(.menuStartTest)

            case .stop:
                Text(.menuStopTest)

            case .tryAgain:
                Text(.menuTryAgain)
            }
        }
    }
#endif
