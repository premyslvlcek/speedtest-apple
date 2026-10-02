//
//  ServerDirectoryLive.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

public extension ServerDirectory {
    static let productionURL: URL = {
        guard let url = URL(string: "https://sp-dir.uwn.com") else {
            preconditionFailure("The directory URL is a constant")
        }
        return url
    }()

    /// The directory over HTTPS. `timeout` is each request's `timeoutInterval`; pass the run's
    /// `SpeedTestConfiguration.directoryTimeout`.
    static func live(
        session: URLSession = .shared,
        baseURL: URL = ServerDirectory.productionURL,
        timeout: Duration
    ) -> ServerDirectory {
        let client = DirectoryHTTPClient(session: session, baseURL: baseURL, timeout: timeout)
        return ServerDirectory(
            fetch: { near in try await client.servers(near: near) },
            token: { try await client.token() },
            clientIP: { try await client.clientIP() }
        )
    }
}

/// The directory's requests and their error rules.
struct DirectoryHTTPClient: Sendable {
    let session: URLSession
    let baseURL: URL
    let timeout: Duration

    func servers(near coordinate: Coordinate?) async throws -> [Server] {
        var queryItems = [URLQueryItem(name: "secured", value: "only")]
        if let coordinate {
            queryItems.append(URLQueryItem(name: "latitude", value: Self.queryValue(coordinate.latitude)))
            queryItems.append(URLQueryItem(name: "longitude", value: Self.queryValue(coordinate.longitude)))
        }
        let url = baseURL.appending(path: "api/v2/servers").appending(queryItems: queryItems)

        let data = try await send(request(url, method: "GET"))
        return try decoded { try ServerDTO.servers(from: data) }
    }

    func token() async throws -> TransferToken {
        var request = request(baseURL.appending(path: "api/v1/tokens"), method: "POST")
        request.httpBody = Data()

        let data = try await send(request)
        let dto = try decoded { try JSONDecoder().decode(TokenDTO.self, from: data) }
        return dto.toDomainModel()
    }

    func clientIP() async throws -> ClientIP {
        let data = try await send(request(baseURL.appending(path: "api/v1/ip"), method: "GET"))
        let dto = try decoded { try JSONDecoder().decode(ClientIPDTO.self, from: data) }
        return dto.toDomainModel()
    }

    /// Every directory request: JSON, this client's timeout, and no local cache.
    func request(_ url: URL, method: String) -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout.inSeconds
        )
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// The body of a 2xx answer. Every failure leaves as a `SpeedTestError`, except cancellation, which stays
    /// a `CancellationError` so that Stop ends the run quietly.
    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard Self.successStatusCodes.contains(http.statusCode) else {
                throw HTTPStatusError(statusCode: http.statusCode)
            }
            return data
        } catch {
            guard let mapped = SpeedTestError.directoryMapping(error) else {
                throw CancellationError()
            }
            throw mapped
        }
    }

    /// HTTP's 2xx range: the request succeeded.
    private static let successStatusCodes = 200 ..< 300

    /// A coordinate with a fixed number of decimals, never in scientific notation. Two decimals is about 1 km, the
    /// accuracy the locator asks for: enough for choosing servers, and no more of the device's position than that.
    private static func queryValue(_ degrees: Double) -> String {
        String(format: coordinateFormat, degrees)
    }

    private static let coordinateFormat = "%.2f"

    /// A body we can't read means the directory is unavailable, whatever the status said.
    private func decoded<T>(_ decode: () throws -> T) throws -> T {
        do {
            return try decode()
        } catch {
            throw SpeedTestError.directoryUnavailable
        }
    }
}
