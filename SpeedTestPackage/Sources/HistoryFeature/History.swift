//
//  History.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import ComposableArchitecture
import Foundation
import SQLiteData

/// Past results, newest first, read live from the database. The speed-test feature writes them; this one lists
/// and deletes them, and neither knows the other's state.
@Reducer
public struct History: Sendable {
    @ObservableState
    public struct State: Equatable {
        @FetchAll(HistoryEntry.order { $0.date.desc() }, animation: .default)
        public var entries: [HistoryEntry]
        @Presents public var confirmation: ConfirmationDialogState<Action.Confirmation>?

        public init() {}
    }

    public enum Action: ViewAction {
        case confirmation(PresentationAction<Confirmation>)
        case view(View)

        @CasePathable
        public enum Confirmation: Sendable, Equatable {
            case clearAll
        }

        @CasePathable
        public enum View: Sendable {
            case clearTapped
            case deleteTapped(IndexSet)
            case doneTapped
        }
    }

    @Dependency(\.defaultDatabase) var database
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .confirmation(.presented(.clearAll)):
                return .run { _ in
                    await withErrorReporting {
                        try await database.write { db in
                            try HistoryEntry.delete().execute(db)
                        }
                    }
                }

            case .confirmation:
                return .none

            case .view(.clearTapped):
                state.confirmation = .clearAll
                return .none

            case let .view(.deleteTapped(offsets)):
                let ids = offsets.map { state.entries[$0].id }
                return .run { _ in
                    await withErrorReporting {
                        try await database.write { db in
                            try HistoryEntry.find(ids).delete().execute(db)
                        }
                    }
                }

            case .view(.doneTapped):
                return .run { _ in
                    await dismiss()
                }
            }
        }
        .ifLet(\.$confirmation, action: \.confirmation)
    }
}

extension ConfirmationDialogState where Action == History.Action.Confirmation {
    static let clearAll = ConfirmationDialogState {
        TextState(.historyClearTitle)
    } actions: {
        ButtonState(role: .destructive, action: .clearAll) {
            TextState(.historyClearConfirm)
        }
    } message: {
        TextState(.historyClearMessage)
    }
}
