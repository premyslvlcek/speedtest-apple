//
//  HistoryClient.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import Dependencies
import DependenciesMacros

/// Saving a finished run. The speed-test feature records runs through this, so it never sees where they're kept.
@DependencyClient
public struct HistoryClient: Sendable {
    public var save: @Sendable (_ entry: HistoryEntry) -> Void = { _ in }
}

public extension DependencyValues {
    @DependencyEntry(liveValue: HistoryClient.live)
    var historyClient = HistoryClient()
}
