//
//  TransferRequest.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// The two requests a transfer repeats. Pure, so the exact URLs and headers are tested.
enum TransferRequest {
    static func download(server: Server, token: TransferToken, bytes: Int, nonce: UInt64) -> URLRequest {
        let url = server.url
            .appending(path: "download")
            .appending(queryItems: [
                URLQueryItem(name: "size", value: String(bytes)),
                URLQueryItem(name: "nc", value: String(nonce))
            ])
        return request(url: url, token: token)
    }

    static func upload(server: Server, token: TransferToken) -> URLRequest {
        var request = request(url: server.url.appending(path: "upload"), token: token)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func request(url: URL, token: TransferToken) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue(token.value, forHTTPHeaderField: "x-test-token")
        // Without this a server that compresses would inflate the result, and no byte counter would show it.
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        return request
    }
}
