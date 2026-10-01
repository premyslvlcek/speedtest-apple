//
//  TransferSession.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import os

/// Parallel connections to one server that only count bytes. Received data is dropped at once, so
/// memory stays flat at any speed. All mutable state sits behind one lock; there is no clock and no sampling
/// here, the transfer meter reads `totalBytes` on its own tick.
final class TransferSession: NSObject, URLSessionDataDelegate, Sendable {
    private struct State: Sendable {
        var ledger: TransferLedger
        var session: URLSession?
        var waiters: [CheckedContinuation<Void, any Error>] = []
        var replies: [Int: Data] = [:]
    }

    private static let logger = Logger(subsystem: "SpeedTestKit", category: "Transfer")

    private let server: Server
    private let direction: TransferDirection
    private let token: TransferToken
    private let configuration: TransferConfiguration
    private let uploadBody: Data
    private let state: OSAllocatedUnfairLock<State>

    init(server: Server, direction: TransferDirection, token: TransferToken, configuration: TransferConfiguration) {
        self.server = server
        self.direction = direction
        self.token = token
        self.configuration = configuration
        // One buffer, allocated once and sent by every upload request.
        uploadBody = direction == .upload ? Self.randomBody(count: configuration.uploadBodyBytes) : Data()
        let ledger = TransferLedger(connections: configuration.connections)
        state = OSAllocatedUnfairLock(initialState: State(ledger: ledger))
        super.init()
    }

    var totalBytes: Int64 {
        state.withLock { $0.ledger.totalBytes }
    }

    var isAlive: Bool {
        state.withLock { $0.ledger.isAlive }
    }

    func start() {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfiguration.httpMaximumConnectionsPerHost = configuration.connections
        // The session holds its delegate strongly until `invalidateAndCancel()` in `cancel()`.
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        state.withLock { $0.session = session }

        for _ in 0 ..< configuration.connections {
            startRequest()
        }
    }

    /// Returns at the first counted byte. Throws the last connection's error if every connection fails first,
    /// and `CancellationError` if the transfer or the waiting task is cancelled.
    func waitForFirstByte() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let immediate: Result<Void, any Error>? = state.withLock { state in
                    if state.ledger.hasFirstByte {
                        return .success(())
                    }
                    if state.ledger.isCancelled {
                        return .failure(CancellationError())
                    }
                    if !state.ledger.isAlive {
                        return .failure(state.ledger.lastError ?? URLError(.cannotConnectToHost))
                    }
                    state.waiters.append(continuation)
                    return nil
                }
                if let immediate {
                    continuation.resume(with: immediate)
                }
            }
        } onCancel: {
            resumeWaiters(with: .failure(CancellationError()))
        }
    }

    func cancel() {
        let (session, waiters) = state.withLock { state in
            state.ledger.cancel()
            let waiters = state.waiters
            state.waiters = []
            return (state.session, waiters)
        }
        session?.invalidateAndCancel()
        waiters.forEach { $0.resume(throwing: CancellationError()) }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard !(200 ..< 300).contains(statusCode) else {
            completionHandler(.allow)
            return
        }

        let taskID = dataTask.taskIdentifier
        state.withLock { $0.ledger.reject(task: taskID, statusCode: statusCode) }
        completionHandler(.cancel)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskID = dataTask.taskIdentifier
        switch direction {
        case .download:
            let bytes = Int64(data.count)
            let isFirstByte = state.withLock { $0.ledger.count(bytes, task: taskID) }
            if isFirstByte {
                resumeWaiters(with: .success(()))
            }

        case .upload:
            // The upload reply is `{"size": N}`, not transferred bytes.
            #if DEBUG
                state.withLock { $0.replies[taskID, default: Data()].append(data) }
            #endif
        }
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent _: Int64,
        totalBytesExpectedToSend _: Int64
    ) {
        guard direction == .upload else {
            return
        }

        // Bytes handed to the socket, not confirmed by the server (the README says so).
        let taskID = task.taskIdentifier
        let isFirstByte = state.withLock { $0.ledger.count(bytesSent, task: taskID) }
        if isFirstByte {
            resumeWaiters(with: .success(()))
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let taskID = task.taskIdentifier
        #if DEBUG
            let reply = state.withLock { $0.replies.removeValue(forKey: taskID) }
            if direction == .upload, error == nil {
                checkUploadReply(reply)
            }
        #endif

        let (completion, failure, waiters) = state.withLock { state in
            let completion = state.ledger.complete(task: taskID, error: error)
            guard completion == .connectionFailed, !state.ledger.isAlive, !state.ledger.hasFirstByte else {
                return (completion, (any Error)?.none, [CheckedContinuation<Void, any Error>]())
            }
            let waiters = state.waiters
            state.waiters = []
            return (completion, state.ledger.lastError, waiters)
        }

        if let failure {
            waiters.forEach { $0.resume(throwing: failure) }
        }
        if completion == .reRequest {
            startRequest()
        }
    }
}

private extension TransferSession {
    /// Starts one request unless the transfer was cancelled. Done under the lock, so a request is never created
    /// on a session that `cancel()` has already invalidated (that would raise an exception).
    func startRequest() {
        state.withLock { state in
            guard !state.ledger.isCancelled, let session = state.session else {
                return
            }

            let task: URLSessionTask = switch direction {
            case .download:
                session.dataTask(with: TransferRequest.download(
                    server: server,
                    token: token,
                    bytes: configuration.downloadRequestBytes,
                    nonce: UInt64.random(in: .min ... .max)
                ))

            case .upload:
                session.uploadTask(with: TransferRequest.upload(server: server, token: token), from: uploadBody)
            }
            task.resume()
        }
    }

    func resumeWaiters(with result: Result<Void, any Error>) {
        let waiters = state.withLock { state in
            let waiters = state.waiters
            state.waiters = []
            return waiters
        }
        waiters.forEach { $0.resume(with: result) }
    }

    #if DEBUG
        /// The server confirms each upload with `{"size": N}`. A mismatch is logged, never asserted.
        func checkUploadReply(_ reply: Data?) {
            struct Reply: Decodable {
                let size: Int
            }

            guard let reply, let decoded = try? JSONDecoder().decode(Reply.self, from: reply) else {
                Self.logger.debug("Upload reply missing or not JSON")
                return
            }
            if decoded.size != uploadBody.count {
                Self.logger.error(
                    "Upload reply size \(decoded.size) differs from the \(self.uploadBody.count) bytes sent"
                )
            }
        }
    #endif

    static func randomBody(count: Int) -> Data {
        var data = Data(count: count)
        data.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else {
                return
            }

            arc4random_buf(base, buffer.count)
        }
        return data
    }
}
