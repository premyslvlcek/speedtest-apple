//
//  HTTPStatusError.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// A non-2xx answer. Live clients throw it; the mapping functions decide what it means.
public struct HTTPStatusError: Error, Sendable, Equatable {
    public let statusCode: Int

    public init(statusCode: Int) {
        self.statusCode = statusCode
    }

    /// 429: the service asks the client to slow down.
    static let tooManyRequests = 429

    /// HTTP's 2xx range; any other status is an error.
    static let successCodes = 200 ..< 300
}
