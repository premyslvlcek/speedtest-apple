//
//  SpeedTestScene.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import HistoryFeature
import SpeedTestKit
import SQLiteData
import SwiftUI

/// The app's only scene. It owns the root store, so the app target needs nothing but this module.
/// One window on the Mac and no multiple scenes on iPad: a second window would share the store.
public struct SpeedTestScene: Scene {
    /// The root store, created once, on first use.
    @MainActor private static let store = makeStore()

    public init() {}

    /// Prepares the app's dependencies, then creates the store. Both happen here, once: dependencies are prepared
    /// once per launch and before anything reads them, and nothing reads them before the store exists.
    @MainActor private static func makeStore() -> StoreOf<SpeedTest> {
        prepareDependencies {
            do {
                $0.defaultDatabase = try historyDatabase(inMemory: LaunchOptions.isScriptedRun)
            } catch {
                reportIssue(error)
            }
            if LaunchOptions.isScriptedRun {
                // A run of a few seconds with no network, location or ICMP.
                $0.locator = .scripted
                $0.serverDirectory = .scripted
                $0.pingService = .scripted
                $0.transferMeter = .scripted
            }
        }
        return Store(initialState: SpeedTest.State()) {
            SpeedTest()
        }
    }

    public var body: some Scene {
        #if os(macOS)
            Window(Text(.appTitle), id: "speed-test") {
                SpeedTestView(store: Self.store)
                    .frame(minWidth: 700, idealWidth: 820, minHeight: 560, idealHeight: 680)
            }
            .windowResizability(.contentSize)
            .commands {
                SpeedTestCommands(store: Self.store)
            }
        #else
            WindowGroup {
                SpeedTestView(store: Self.store)
            }
        #endif
    }
}
