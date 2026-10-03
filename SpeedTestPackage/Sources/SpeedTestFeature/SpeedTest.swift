//
//  SpeedTest.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import Foundation
import HistoryFeature
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
        /// The public address this run started from, looked up on Start. `nil` until it answers, or if it can't.
        public var clientIP: ClientIP?
        @Presents public var history: History.State?
        /// Whether a run measures upload after the download. Off by default: the test is the 15 s download.
        /// Remembered across launches.
        @Shared(.appStorage("measuresUpload")) public var measuresUpload = false
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
        case clientIPResponse(Result<ClientIP, any Error>)
        case history(PresentationAction<History.Action>)
        case located(LocationOutcome)
        case serversResponse(Result<[Server], any Error>)
        case pinged(host: String, PingResult)
        case tokenResponse(Result<TransferToken, any Error>)
        case sampled(TransferDirection, ThroughputSample)
        /// A measurement's stream finished (`.success`) or failed.
        case transferResponse(TransferDirection, Result<Void, any Error>)
        case view(View)

        @CasePathable
        public enum View: Sendable {
            case historyTapped
            case openSettingsTapped
            case retryTapped
            case scenePhaseChanged(ScenePhase)
            case startStopTapped
            case uploadToggled(Bool)
        }
    }

    static let configuration = SpeedTestConfiguration.standard

    @Dependency(\.date.now) var now
    @Dependency(\.historyClient) var historyClient
    @Dependency(\.locator) var locator
    @Dependency(\.openURL) var openURL
    @Dependency(\.pingService) var pingService
    @Dependency(\.serverDirectory) var serverDirectory
    @Dependency(\.transferMeter) var transferMeter

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .clientIPResponse(.success(clientIP)):
                state.clientIP = clientIP

                return .none

            case .clientIPResponse(.failure):
                // The address is extra information: without it the run goes on and the line stays hidden.
                return .none

            case .history:
                return .none

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

                return measureDownload(state: &state)

            case let .sampled(direction, sample):
                state.record(sample, direction)

                return .none

            case .transferResponse(.download, .success):
                return downloadFinished(state: &state)

            case let .transferResponse(.download, .failure(error)):
                return downloadFailed(error, state: &state)

            case .transferResponse(.upload, .success):
                state.finishUpload()

                return saveIfFinished(state: state)

            case let .transferResponse(.upload, .failure(error)):
                state.uploadFailed(error)

                return saveIfFinished(state: state)

            case .view(.historyTapped):
                state.history = History.State()

                return .none

            case .view(.openSettingsTapped):
                return .run { _ in
                    await openURL(Self.settingsURL)
                }

            case .view(.retryTapped):
                return start(state: &state)

            case let .view(.scenePhaseChanged(scenePhase)):
                return scenePhaseChanged(scenePhase, state: &state)

            case let .view(.uploadToggled(isOn)):
                guard !state.isRunning else {
                    return .none
                }

                state.$measuresUpload.withLock { $0 = isOn }

                return .none

            case .view(.startStopTapped):
                guard state.isRunning else {
                    return start(state: &state)
                }

                state.interrupt(.stopped)

                return .cancel(id: SpeedTestId())
            }
        }
        .ifLet(\.$history, action: \.history) {
            History()
        }
    }
}

/// Every effect of a run: Stop and the background cancel them all at once.
struct SpeedTestId: Hashable, Sendable {}

/// The address lookup that starts with each run. Not one of the run's effects: Stop lets it finish.
struct ClientIPId: Hashable, Sendable {}

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
