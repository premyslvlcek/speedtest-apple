//
//  TransferLedgerTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import Testing

@testable import SpeedTestKit

@Suite struct TransferLedgerTests {
    @Test func theFirstCountedBytesAreTheFirstByte() {
        var ledger = TransferLedger(connections: 4)

        let first = ledger.count(100, task: 1)
        let second = ledger.count(50, task: 2)

        #expect(first)
        #expect(!second)
        #expect(ledger.totalBytes == 150)
        #expect(ledger.hasFirstByte)
    }

    @Test func zeroBytesDoNotCount() {
        var ledger = TransferLedger(connections: 4)

        let isFirstByte = ledger.count(0, task: 1)

        #expect(!isFirstByte)
        #expect(!ledger.hasFirstByte)
    }

    @Test func aRejectedTaskGivesItsBytesBackAndCountsNothingMore() {
        var ledger = TransferLedger(connections: 4)
        _ = ledger.count(100, task: 1)
        _ = ledger.count(50, task: 2)

        ledger.reject(task: 1, statusCode: 401)
        #expect(ledger.totalBytes == 50)

        _ = ledger.count(10, task: 1)
        #expect(ledger.totalBytes == 50)
    }

    @Test func aFinishedBodyAsksAgain() {
        var ledger = TransferLedger(connections: 4)
        _ = ledger.count(100, task: 1)

        let completion = ledger.complete(task: 1, error: nil)

        #expect(completion == .reRequest)
        #expect(ledger.aliveConnections == 4)
        #expect(ledger.totalBytes == 100)
    }

    @Test func aFailedConnectionIsNotRetried() {
        var ledger = TransferLedger(connections: 2)

        let completion = ledger.complete(task: 1, error: URLError(.networkConnectionLost))

        #expect(completion == .connectionFailed)
        #expect(ledger.aliveConnections == 1)
        #expect((ledger.lastError as? URLError)?.code == .networkConnectionLost)
        #expect(ledger.isAlive)
    }

    @Test func aRejectedTaskFailsWithItsStatusNotWithTheCancellation() {
        var ledger = TransferLedger(connections: 2)
        ledger.reject(task: 1, statusCode: 429)

        // We cancelled the task in didReceive(response:), so URLSession reports it as cancelled.
        let completion = ledger.complete(task: 1, error: URLError(.cancelled))

        #expect(completion == .connectionFailed)
        #expect(ledger.lastError as? HTTPStatusError == HTTPStatusError(statusCode: 429))
        #expect(ledger.wasRefused)
    }

    /// A connection lost before the last one was refused: the transfer was lost, not refused.
    @Test func itWasRefusedOnlyIfEveryFailedConnectionWasRefused() {
        var ledger = TransferLedger(connections: 2)
        _ = ledger.complete(task: 1, error: URLError(.networkConnectionLost))
        ledger.reject(task: 2, statusCode: 500)
        _ = ledger.complete(task: 2, error: URLError(.cancelled))

        #expect(ledger.lastError as? HTTPStatusError == HTTPStatusError(statusCode: 500))
        #expect(!ledger.wasRefused)
    }

    @Test func everyConnectionFailedMeansNotAlive() {
        var ledger = TransferLedger(connections: 2)
        _ = ledger.complete(task: 1, error: URLError(.cannotConnectToHost))
        _ = ledger.complete(task: 2, error: URLError(.serverCertificateUntrusted))

        #expect(!ledger.isAlive)
        #expect((ledger.lastError as? URLError)?.code == .serverCertificateUntrusted)
        #expect(!ledger.wasRefused)
    }

    @Test func afterCancelNothingCountsAndCompletionsAreIgnored() {
        var ledger = TransferLedger(connections: 2)
        _ = ledger.count(100, task: 1)

        ledger.cancel()
        let isFirstByte = ledger.count(100, task: 1)
        let completion = ledger.complete(task: 1, error: URLError(.cancelled))

        #expect(!isFirstByte)
        #expect(ledger.totalBytes == 100)
        #expect(completion == .ignored)
        #expect(!ledger.isAlive)
    }
}
