//
//  PingServiceLive.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Dependencies
import ICMP

public extension PingService {
    /// A fresh `Pinger` for every call, so every host gets its own connected socket, identifier and token, and
    /// replies can't be credited to the wrong server. Its timing runs on the registered `continuousClock`,
    /// resolved when this value is created.
    static var live: PingService {
        @Dependency(\.continuousClock) var clock
        return PingService(ping: { host, configuration in
            await Pinger(host: host, clock: clock).ping(configuration)
        })
    }
}
