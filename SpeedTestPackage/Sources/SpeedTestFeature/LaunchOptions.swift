//
//  LaunchOptions.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import Foundation

/// Launch arguments for the UI test. Debug builds only: a release build ignores them.
enum LaunchOptions {
    /// Runs on the scripted clients (no network, location or ICMP) with a history kept in memory.
    static let isScriptedRun: Bool = {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("-scriptedRun")
        #else
            false
        #endif
    }()
}
