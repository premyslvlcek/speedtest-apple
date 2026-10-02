//
//  SpeedTestScene.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import HistoryFeature
import SQLiteData
import SwiftUI

/// The app's only scene. It owns the root store, so the app target needs nothing but this module.
/// One window on the Mac and no multiple scenes on iPad: a second window would share the store.
public struct SpeedTestScene: Scene {
    /// Created once, on first use. The history database is set up first, so nothing reads the default
    /// dependency before it's migrated.
    @MainActor private static let store: StoreOf<SpeedTest> = {
        prepareDependencies {
            do {
                $0.defaultDatabase = try historyDatabase()
            } catch {
                reportIssue(error)
            }
        }
        return Store(initialState: SpeedTest.State()) {
            SpeedTest()
        }
    }()

    public init() {}

    public var body: some Scene {
        #if os(macOS)
            Window(Text(.appTitle), id: "speed-test") {
                SpeedTestView(store: Self.store)
                    .frame(minWidth: 380, idealWidth: 420, minHeight: 600, idealHeight: 720)
            }
            .windowResizability(.contentSize)
        #else
            WindowGroup {
                SpeedTestView(store: Self.store)
            }
        #endif
    }
}
