//
//  StubURLProtocol.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import os

/// How a stubbed request is answered.
enum StubOutcome: Sendable {
    case response(statusCode: Int, body: Data)
    case failure(URLError)
}

/// Answers requests from a per-test handler instead of the network.
final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) -> StubOutcome

    private static let handlers = OSAllocatedUnfairLock<[String: Handler]>(initialState: [:])

    /// A session and a base URL on a host of its own. Requests to that host are answered by `handler`.
    static func make(handler: @escaping Handler) -> (session: URLSession, baseURL: URL) {
        let host = "\(UUID().uuidString.lowercased()).stub.test"
        handlers.withLock { $0[host] = handler }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        guard let baseURL = components.url else {
            preconditionFailure("Invalid stub host: \(host)")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return (URLSession(configuration: configuration), baseURL)
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let host = request.url?.host() ?? ""
        guard let url = request.url, let handler = Self.handlers.withLock({ $0[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        switch handler(request) {
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)

        case let .response(statusCode, body):
            guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
