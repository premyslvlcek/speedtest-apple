//
//  TransferRequestTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import Testing

@testable import SpeedTestKit

@Suite struct TransferRequestTests {
    private let token = TransferToken(value: "4f1c2e9a-token")

    private func server() throws -> Server {
        try Server(
            url: #require(URL(string: "https://fast.example.invalid:4780")),
            host: "fast.example.invalid",
            coordinate: Coordinate(latitude: 50.08, longitude: 14.42),
            provider: "Example",
            city: "Prague"
        )
    }

    @Test func downloadAsksForTheSizeWithACacheBuster() throws {
        let request = try TransferRequest.download(server: server(), token: token, bytes: 50_000_000, nonce: 42)

        #expect(request.url?.absoluteString == "https://fast.example.invalid:4780/download?size=50000000&nc=42")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "x-test-token") == "4f1c2e9a-token")
        #expect(request.value(forHTTPHeaderField: "Accept-Encoding") == "identity")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test func uploadPostsOctetStreamAndAsksForJSON() throws {
        let request = try TransferRequest.upload(server: server(), token: token)

        #expect(request.url?.absoluteString == "https://fast.example.invalid:4780/upload")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "x-test-token") == "4f1c2e9a-token")
        #expect(request.value(forHTTPHeaderField: "Accept-Encoding") == "identity")
    }
}
