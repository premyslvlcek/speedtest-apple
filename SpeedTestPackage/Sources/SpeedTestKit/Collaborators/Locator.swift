//
//  Locator.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import DependenciesMacros

/// Finds the device's position once, for choosing servers.
@DependencyClient
public struct Locator: Sendable {
    /// Waits for the user's answer to the permission prompt with no time limit, then at most `timeout` for a fix.
    public var locate: @Sendable (_ timeout: Duration) async -> LocationOutcome = { _ in .unavailable }
}

public extension DependencyValues {
    @DependencyEntry var locator = Locator()
}
