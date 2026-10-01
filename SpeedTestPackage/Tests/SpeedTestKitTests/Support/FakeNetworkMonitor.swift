//
//  FakeNetworkMonitor.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ConcurrencyExtras
import SpeedTestKit

/// A network monitor the test drives. Every `interfaceChanges()` call is a new watch; `changeInterface()`
/// reports a change to all of them.
final class FakeNetworkMonitor: Sendable {
    private let watchers = LockIsolated<[AsyncStream<Void>.Continuation]>([])
    private let subscriptionsContinuation: AsyncStream<Void>.Continuation
    /// Yields once whenever the engine starts a watch.
    let subscriptions: AsyncStream<Void>

    init() {
        (subscriptions, subscriptionsContinuation) = AsyncStream.makeStream()
    }

    var watchCount: Int {
        watchers.value.count
    }

    var monitor: NetworkMonitor {
        NetworkMonitor(interfaceChanges: {
            let (stream, continuation) = AsyncStream<Void>.makeStream()
            self.watchers.withValue { $0.append(continuation) }
            self.subscriptionsContinuation.yield()
            return stream
        })
    }

    func changeInterface() {
        for watcher in watchers.value {
            watcher.yield()
        }
    }
}
