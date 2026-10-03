//
//  History.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import ComposableArchitecture
import Foundation

/// Past results, newest first, from the shared history file. The speed-test feature adds to it; this one lists
/// and deletes, and neither knows the other's state.
@Reducer
public struct History: Sendable {
    @ObservableState
    public struct State: Equatable {
        @Shared(.history) public var entries
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    public enum Action: ViewAction {
        case alert(PresentationAction<Alert>)
        case view(View)

        @CasePathable
        public enum Alert: Sendable, Equatable {
            case clearAll
        }

        @CasePathable
        public enum View: Sendable {
            case clearTapped
            case deleteTapped(IndexSet)
            case doneTapped
        }
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.clearAll)):
                state.$entries.withLock { $0.removeAll() }

                return saveNow(state)

            case .alert:
                return .none

            case .view(.clearTapped):
                state.alert = .clearAll

                return .none

            case let .view(.deleteTapped(offsets)):
                state.$entries.withLock { entries in
                    for offset in offsets.reversed() {
                        entries.remove(at: offset)
                    }
                }

                return saveNow(state)

            case .view(.doneTapped):
                return .run { _ in
                    await dismiss()
                }
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// Writes the history now. The file storage delays a change that follows another within a second, and drops it
    /// if the history is released first: the sheet closing right after a delete.
    private func saveNow(_ state: State) -> Effect<Action> {
        .run { [entries = state.$entries] _ in
            await withErrorReporting {
                try await entries.save()
            }
        }
    }
}

/// An alert, not a confirmation dialog: one irreversible action, laid out full width at any text size, and not
/// a popover pointing at whatever the dialog was attached to.
extension AlertState where Action == History.Action.Alert {
    static let clearAll = AlertState {
        TextState(.historyClearTitle)
    } actions: {
        ButtonState(role: .cancel) {
            TextState(.historyCancel)
        }
        ButtonState(role: .destructive, action: .clearAll) {
            TextState(.historyClearConfirm)
        }
    } message: {
        TextState(.historyClearMessage)
    }
}
