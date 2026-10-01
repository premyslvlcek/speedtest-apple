//
//  TransferLedger.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The bookkeeping of one transfer: which bytes count, when the first byte arrived, and how many connections
/// are still alive. Pure, so these rules are tested without a network.
struct TransferLedger: Sendable {
    enum Completion: Sendable, Equatable {
        /// The body finished; the connection asks again so the line stays saturated.
        case reRequest
        /// The connection failed and is not retried.
        case connectionFailed
        /// The whole transfer was cancelled; nothing to do.
        case ignored
    }

    private(set) var totalBytes: Int64 = 0
    private(set) var hasFirstByte = false
    private(set) var aliveConnections: Int
    private(set) var lastError: (any Error)?
    private(set) var isCancelled = false
    private var bytesByTask: [Int: Int64] = [:]
    private var rejectedTasks: [Int: HTTPStatusError] = [:]

    init(connections: Int) {
        aliveConnections = connections
    }

    var isAlive: Bool {
        aliveConnections > 0
    }

    /// Counts bytes moved by a task. Returns `true` when these are the transfer's first bytes.
    mutating func count(_ bytes: Int64, task: Int) -> Bool {
        guard bytes > 0, !isCancelled, rejectedTasks[task] == nil else {
            return false
        }

        bytesByTask[task, default: 0] += bytes
        totalBytes += bytes
        guard !hasFirstByte else {
            return false
        }

        hasFirstByte = true
        return true
    }

    /// A non-2xx answer (401, 429, 5xx): the task's bytes are taken back out and it counts nothing more.
    /// This matters for upload, where bytes are counted as they are sent, before the status arrives.
    mutating func reject(task: Int, statusCode: Int) {
        rejectedTasks[task] = HTTPStatusError(statusCode: statusCode)
        totalBytes -= bytesByTask.removeValue(forKey: task) ?? 0
    }

    /// A task ended. A finished body means the connection asks again; an error means it is gone for good.
    mutating func complete(task: Int, error: (any Error)?) -> Completion {
        bytesByTask[task] = nil
        let rejection = rejectedTasks.removeValue(forKey: task)
        guard !isCancelled else {
            return .ignored
        }

        if let rejection {
            return fail(with: rejection)
        }
        guard let error else {
            return .reRequest
        }

        return fail(with: error)
    }

    mutating func cancel() {
        isCancelled = true
    }

    private mutating func fail(with error: any Error) -> Completion {
        lastError = error
        aliveConnections = max(aliveConnections - 1, 0)
        return .connectionFailed
    }
}
