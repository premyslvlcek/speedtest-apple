//
//  MainSerialExecutorTrait.swift
//  TestSupport
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ConcurrencyExtras
import Testing

/// Runs a suite's tests on the main serial executor, as Point-Free recommend for testing async code
/// ("Reliably testing async code" in swift-concurrency-extras): every task runs in order, one at a time, so
/// clocks' yields and the code under test interleave deterministically.
///
/// The executor switch is process-wide and Swift Testing runs suites in parallel, so `withMainSerialExecutor`
/// alone would let one test switch it off under another. This trait counts the tests using it and keeps the
/// switch on until the last one has finished. Other tests running meanwhile are serialized too, which is slower
/// but not wrong.
public struct MainSerialExecutorTrait: SuiteTrait, TestTrait, TestScoping {
    public var isRecursive: Bool {
        true
    }

    @concurrent
    public func provideScope(
        for _: Test,
        testCase: Test.Case?,
        performing function: @concurrent @Sendable () async throws -> Void
    ) async throws {
        // A suite's scope wraps its tests' scopes; counting only the tests is enough.
        guard testCase != nil else {
            try await function()
            return
        }
        Self.users.withValue { count in
            if count == 0 {
                uncheckedUseMainSerialExecutor = true
            }
            count += 1
        }
        defer {
            Self.users.withValue { count in
                count -= 1
                if count == 0 {
                    uncheckedUseMainSerialExecutor = false
                }
            }
        }
        try await function()
    }

    /// How many tests are running under this trait right now.
    private static let users = LockIsolated(0)
}

public extension Trait where Self == MainSerialExecutorTrait {
    /// Runs the tests on the main serial executor; see `MainSerialExecutorTrait`.
    static var mainSerialExecutor: Self {
        Self()
    }
}
