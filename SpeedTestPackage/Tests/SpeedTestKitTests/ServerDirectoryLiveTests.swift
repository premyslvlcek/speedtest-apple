//
//  ServerDirectoryLiveTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ConcurrencyExtras
import Foundation
import Testing

@testable import SpeedTestKit

@Suite struct ServerDirectoryLiveTests {
    static let prague = Coordinate(latitude: 50.0755, longitude: 14.4378)

    @Test func fetchAsksForHTTPSServersNearTheCoordinate() async throws {
        let (directory, requests) = try Self.recordingDirectory(answering: "servers")

        let servers = try await directory.fetch(near: Self.prague)

        #expect(!servers.isEmpty)
        let request = try #require(requests.value.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path() == "/api/v2/servers")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(Self.queryItems(of: request) == [
            URLQueryItem(name: "secured", value: "only"),
            URLQueryItem(name: "latitude", value: "50.08"),
            URLQueryItem(name: "longitude", value: "14.44")
        ])
    }

    /// Two decimals is about 1 km: enough to pick servers, and no more of the device's position than that.
    @Test func theCoordinateIsSentWithTwoDecimalsNeverInScientificNotation() async throws {
        let (directory, requests) = try Self.recordingDirectory(answering: "servers")

        _ = try await directory.fetch(near: Coordinate(latitude: 0.00001, longitude: -0.123456))

        let request = try #require(requests.value.first)
        #expect(Self.queryItems(of: request).dropFirst() == [
            URLQueryItem(name: "latitude", value: "0.00"),
            URLQueryItem(name: "longitude", value: "-0.12")
        ])
    }

    @Test func approximateModeLetsTheDirectoryLocateUsByIP() async throws {
        let (directory, requests) = try Self.recordingDirectory(answering: "servers")

        _ = try await directory.fetch(near: nil)

        let request = try #require(requests.value.first)
        #expect(Self.queryItems(of: request) == [URLQueryItem(name: "secured", value: "only")])
    }

    @Test func tokenIsAPostThatReturnsTheTokenAndItsLifetime() async throws {
        let (directory, requests) = try Self.recordingDirectory(answering: "token")

        let token = try await directory.token()

        #expect(token == TransferToken(value: "377c603e-d8c6-422b-892f-bdac396258fc", ttl: .seconds(80)))
        let request = try #require(requests.value.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/api/v1/tokens")
        #expect(request.url?.query() == nil)
    }

    @Test func clientIPReadsTheAddressAndTheProvider() async throws {
        let (directory, requests) = try Self.recordingDirectory(answering: "client-ip")

        let clientIP = try await directory.clientIP()

        #expect(clientIP == ClientIP(address: "203.0.113.7", provider: "Example Networks a.s."))
        let request = try #require(requests.value.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path() == "/api/v1/ip")
    }

    @Test(arguments: directoryFailures)
    func fetchFailuresFollowTheErrorTable(outcome: StubOutcome, expected: SpeedTestError) async {
        let stub = StubURLProtocol.make { _ in outcome }
        let directory = ServerDirectory.live(session: stub.session, baseURL: stub.baseURL, timeout: .seconds(10))

        await #expect(throws: expected) {
            try await directory.fetch(near: nil)
        }
    }

    @Test(arguments: tokenFailures)
    func tokenFailuresFollowTheSameTable(outcome: StubOutcome, expected: SpeedTestError) async {
        // The token request shares the error handling with the list, so this only proves its own wiring.
        let stub = StubURLProtocol.make { _ in outcome }
        let directory = ServerDirectory.live(session: stub.session, baseURL: stub.baseURL, timeout: .seconds(10))

        await #expect(throws: expected) {
            try await directory.token()
        }
    }

    @Test func aCancelledRequestStaysACancellation() async {
        // Stop must end the run quietly, not show "directory unavailable".
        let stub = StubURLProtocol.make { _ in .failure(URLError(.cancelled)) }
        let directory = ServerDirectory.live(session: stub.session, baseURL: stub.baseURL, timeout: .seconds(10))

        await #expect(throws: CancellationError.self) {
            try await directory.fetch(near: nil)
        }
    }

    @Test func requestsCarryTheClientsTimeoutAndSkipTheLocalCache() throws {
        // Checked on the built request: a URLProtocol may see a copy with the session's defaults.
        let url = try #require(URL(string: "https://sp-dir.uwn.com/api/v2/servers"))
        let client = DirectoryHTTPClient(session: .shared, baseURL: url, timeout: .seconds(7))

        let request = client.request(url, method: "GET")

        #expect(request.timeoutInterval == 7)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    /// A live directory whose every request is recorded and answered with the named fixture.
    private static func recordingDirectory(
        answering fixture: String
    ) throws -> (directory: ServerDirectory, requests: LockIsolated<[URLRequest]>) {
        let body = try Fixture.data(fixture)
        let requests = LockIsolated<[URLRequest]>([])
        let stub = StubURLProtocol.make { request in
            requests.withValue { $0.append(request) }
            return .response(statusCode: 200, body: body)
        }
        return (ServerDirectory.live(session: stub.session, baseURL: stub.baseURL, timeout: .seconds(10)), requests)
    }

    private static func queryItems(of request: URLRequest) -> [URLQueryItem] {
        guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return []
        }
        return components.queryItems ?? []
    }
}

/// Offline codes (and a dropped connection) → offline, 429 → rate limited, everything else → unavailable.
private let directoryFailures: [(StubOutcome, SpeedTestError)] = [
    // The mapping itself is pinned in ErrorMappingTests; these rows prove the list request uses the directory's
    // mapping: a dropped connection is offline here (a run would call it a transfer failure), 429 is busy, any
    // other status or an unreadable body means unavailable.
    (.failure(URLError(.networkConnectionLost)), .offline),
    (.response(statusCode: 429, body: Data()), .rateLimited),
    (.response(statusCode: 200, body: Data("<html>busy</html>".utf8)), .directoryUnavailable)
]

/// The token request: a mapped status and an unreadable body.
private let tokenFailures: [(StubOutcome, SpeedTestError)] = [
    (.response(statusCode: 429, body: Data()), .rateLimited),
    (.response(statusCode: 200, body: Data("<html>busy</html>".utf8)), .directoryUnavailable)
]
