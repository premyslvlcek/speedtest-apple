//
//  TransferSessionTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 03.10.2026.
//

import Foundation
import Testing

@testable import SpeedTestKit

@Suite(.timeLimit(.minutes(1))) struct TransferSessionTests {
    /// Stop can land just as the meter starts waiting: the waiting task is already cancelled when it asks. It must
    /// return at once, not wait for a first byte that may never come (the connections run on until they time out).
    @Test func waitingFromACancelledTaskReturnsAtOnce() async {
        let session = TransferSession(
            server: .fixture("vinohrady"),
            direction: .download,
            token: TransferToken(value: "token-1"),
            configuration: TransferConfiguration()
        )

        let threw = await withTaskGroup(of: Bool?.self) { group in
            group.addTask {
                withUnsafeCurrentTask { $0?.cancel() }
                do {
                    try await session.waitForFirstByte()
                    return false
                } catch {
                    return error is CancellationError
                }
            }
            // If the waiter were left waiting, this releases it with another error, so the test fails instead of
            // hanging. It keeps trying until the waiter has answered, since the waiter may not be waiting yet. When
            // the wait returned at once there is no waiter, and this changes nothing.
            group.addTask {
                while !Task.isCancelled {
                    session.resumeWaiters(with: .failure(URLError(.timedOut)))
                    await Task.yield()
                }
                return nil
            }
            var threw = false
            for await result in group {
                if let result {
                    threw = result
                    group.cancelAll()
                }
            }
            return threw
        }

        #expect(threw)
    }
}
