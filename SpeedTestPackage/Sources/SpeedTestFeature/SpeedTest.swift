//
//  SpeedTest.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import Foundation
import ICMP
import SpeedTestKit
import SwiftUI

/// The one screen: Start/Stop, the live measurement and the closest servers. The reducer drives the run itself,
/// one action per step; the dependency clients only do the I/O.
@Reducer
public struct SpeedTest: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var phase: Phase = .idle
        public var location: LocationOutcome?
        public var candidates: IdentifiedArrayOf<Candidate> = []
        public var selection: Selection?
        public var downloadSamples: [ThroughputSample] = []
        public var uploadSamples: [ThroughputSample] = []
        public var download: TransferResult?
        public var upload: TransferResult?
        public var isUploadUnavailable = false
        /// The fallback order, set once every host has answered.
        var order: [Candidate] = []
        /// Fetched once per run, right before the download.
        var token: TransferToken?
        /// Failover happens once per run.
        var hasFailedOver = false

        public init() {}
    }

    public enum Phase: Sendable, Equatable {
        case idle
        case locating
        case fetchingServers
        case pinging
        case connecting(TransferDirection)
        case downloading
        case uploading
        case finished
        case interrupted(Interruption)
        case failed(SpeedTestError)
    }

    public enum Interruption: Sendable, Equatable {
        case stopped
        case background
        case networkChanged
        case connectionLost
    }

    public struct Selection: Sendable, Equatable {
        public var server: Server
        public var ping: PingResult?
        public var reason: SelectionReason

        public init(server: Server, ping: PingResult?, reason: SelectionReason) {
            self.server = server
            self.ping = ping
            self.reason = reason
        }
    }

    public enum Action: ViewAction {
        case located(LocationOutcome)
        case serversResponse(Result<[Server], any Error>)
        case pinged(host: String, PingResult)
        case tokenResponse(Result<TransferToken, any Error>)
        case view(View)

        @CasePathable
        public enum View: Sendable {
            case openSettingsTapped
            case retryTapped
            case scenePhaseChanged(ScenePhase)
            case startStopTapped
        }
    }

    static let configuration = SpeedTestConfiguration.standard

    @Dependency(\.locator) var locator
    @Dependency(\.openURL) var openURL
    @Dependency(\.pingService) var pingService
    @Dependency(\.serverDirectory) var serverDirectory

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .located(outcome):
                return located(outcome, state: &state)

            case let .serversResponse(.success(servers)):
                return serversFound(servers, state: &state)

            case let .serversResponse(.failure(error)), let .tokenResponse(.failure(error)):
                guard let error = SpeedTestError.directoryMapping(error) else {
                    return .none
                }

                state.phase = .failed(error)

                return .none

            case let .pinged(host, result):
                return pinged(host, result, state: &state)

            case let .tokenResponse(.success(token)):
                state.token = token

                return .none

            case .view(.openSettingsTapped):
                return .run { _ in
                    await openURL(Self.settingsURL)
                }

            case .view(.retryTapped):
                return start(state: &state)

            case let .view(.scenePhaseChanged(scenePhase)):
                return scenePhaseChanged(scenePhase, state: &state)

            case .view(.startStopTapped):
                guard state.isRunning else {
                    return start(state: &state)
                }

                state.interrupt(.stopped)

                return .cancel(id: SpeedTestId())
            }
        }
    }
}

/// Every effect of a run: Stop and the background cancel them all at once.
struct SpeedTestId: Hashable, Sendable {}

extension SpeedTest {
    /// The app's own settings page on iOS; the Location Services privacy pane on macOS.
    static let settingsURL: URL = {
        #if os(iOS)
            // The value of `UIApplication.openSettingsURLString`, which is main-actor isolated.
            let string = "app-settings:"
        #else
            let string = "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        #endif
        guard let url = URL(string: string) else {
            preconditionFailure("The settings URL is a constant")
        }
        return url
    }()
}
