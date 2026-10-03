//
//  HistoryClientLive.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import ComposableArchitecture

public extension HistoryClient {
    /// Puts the run first in the shared history, which writes it to its file. Runs are far more than a second
    /// apart, so the file storage writes each one at once.
    static var live: HistoryClient {
        HistoryClient(save: { entry in
            @Shared(.history) var entries
            $entries.withLock { $0.insert(entry, at: 0) }
        })
    }
}
