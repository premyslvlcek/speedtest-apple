//
//  PingConfiguration.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// How one `ping()` call behaves.
public struct PingConfiguration: Sendable, Equatable {
    /// How many echo requests are sent: 1 to 65 536, because each one gets its own 16-bit sequence number.
    public var count: Int
    /// The pause between two requests.
    public var interval: Duration
    /// How long each request waits for its reply, measured from its own send.
    public var timeout: Duration

    public init(count: Int = 5, interval: Duration = .milliseconds(100), timeout: Duration = .seconds(1)) {
        self.count = count
        self.interval = interval
        self.timeout = timeout
    }

    public static let standard = PingConfiguration()
}
