//
//  NetworkMonitor.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import DependenciesMacros

/// Reports when the network the test runs on goes away or changes its primary interface.
@DependencyClient
public struct NetworkMonitor: Sendable {
    /// Each call starts a new watch. The first path is the baseline and isn't reported.
    public var interfaceChanges: @Sendable () -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}
