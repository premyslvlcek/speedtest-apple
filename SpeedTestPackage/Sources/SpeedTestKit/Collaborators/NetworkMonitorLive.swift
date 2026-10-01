//
//  NetworkMonitorLive.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import Network
import os

public extension NetworkMonitor {
    /// Yields when the path becomes unusable or its primary interface changes. The path `NWPathMonitor` delivers
    /// right after `start()` is the baseline and is not yielded. Listening ends, and the monitor is cancelled,
    /// when the consumer stops iterating.
    static let live = NetworkMonitor(interfaceChanges: {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let baseline = OSAllocatedUnfairLock<PathSnapshot?>(initialState: nil)

            monitor.pathUpdateHandler = { path in
                let current = PathSnapshot(path)
                let isInterruption = baseline.withLock { stored -> Bool in
                    guard let existing = stored else {
                        stored = current
                        return false
                    }
                    return PathSnapshot.isInterruption(baseline: existing, current: current)
                }
                if isInterruption {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue(label: "SpeedTestKit.NetworkMonitor"))
        }
    })
}

extension PathSnapshot {
    init(_ path: NWPath) {
        self.init(
            isSatisfied: path.status == .satisfied,
            primaryInterface: path.availableInterfaces.first.map { Self.interface(for: $0.type) }
        )
    }

    private static func interface(for type: NWInterface.InterfaceType) -> Interface {
        switch type {
        case .wifi:
            .wifi

        case .cellular:
            .cellular

        case .wiredEthernet:
            .wired

        case .loopback, .other:
            .other

        @unknown default:
            .other
        }
    }
}
