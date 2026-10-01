//
//  SpeedTest+Run.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import ComposableArchitecture
import ICMP
import SpeedTestKit
import SwiftUI

/// The steps of a run. Each handler updates the state and starts the next step's effect.
extension SpeedTest {
    /// Start and Retry: a clean screen, then locate.
    func start(state: inout State) -> Effect<Action> {
        state.reset()
        state.phase = .locating
        let timeout = Self.configuration.locationTimeout

        return .run { send in
            await send(.located(locator.locate(timeout)))
        }
        .cancellable(id: SpeedTestId(), cancelInFlight: true)
    }

    func located(_ outcome: LocationOutcome, state: inout State) -> Effect<Action> {
        state.location = outcome
        state.phase = .fetchingServers

        return .run { send in
            await send(.serversResponse(Result { try await serverDirectory.fetch(outcome.coordinate) }))
        }
        .cancellable(id: SpeedTestId())
    }

    /// Picks the candidates and pings every distinct host once, all at the same time.
    func serversFound(_ servers: [Server], state: inout State) -> Effect<Action> {
        let candidates = ServerSelector.candidates(
            from: servers,
            location: state.location?.coordinate,
            nearestCount: Self.configuration.nearestCount,
            approximateCount: Self.configuration.approximateCount
        )
        guard !candidates.isEmpty else {
            state.phase = .failed(.noServers)

            return .none
        }

        state.candidates = IdentifiedArray(uniqueElements: candidates)
        state.phase = .pinging
        let hosts = candidates.map(\.server.host).reduce(into: [String]()) { hosts, host in
            if !hosts.contains(host) {
                hosts.append(host)
            }
        }
        let configuration = Self.configuration.ping

        return .run { send in
            await withTaskGroup(of: (host: String, result: PingResult).self) { group in
                for host in hosts {
                    group.addTask {
                        await (host, pingService.ping(host, configuration))
                    }
                }
                for await (host, result) in group {
                    await send(.pinged(host: host, result))
                }
            }
        }
        .cancellable(id: SpeedTestId())
    }

    /// Shows the result on every entry of the host. Once every host has answered, chooses the server and asks
    /// for the token.
    func pinged(_ host: String, _ result: PingResult, state: inout State) -> Effect<Action> {
        for candidate in state.candidates where candidate.server.host == host {
            state.candidates[id: candidate.id]?.ping = .finished(result)
        }
        guard !state.candidates.contains(where: { $0.ping == .pending }) else {
            return .none
        }

        state.order = ServerSelector.order(
            state.candidates.elements,
            minimumReplies: Self.configuration.minimumReplies
        )
        let fastest = state.order[0]
        state.select(fastest, reason: fastest.pingResult?.isReachable == true ? .lowestPing : .icmpBlocked)
        state.phase = .connecting(.download)

        return .run { send in
            await send(.tokenResponse(Result { try await serverDirectory.token() }))
        }
        .cancellable(id: SpeedTestId())
    }

    /// Measures the download on the selected server with the run's token.
    func measureDownload(state: State) -> Effect<Action> {
        guard let server = state.selection?.server, let token = state.token else {
            return .none
        }

        return measure(.download, on: server, token: token)
    }

    /// The download finished: the upload follows on the same server, with the same token.
    func downloadFinished(state: inout State) -> Effect<Action> {
        guard let last = state.downloadSamples.last, let server = state.selection?.server, let token = state.token
        else {
            state.phase = .failed(.transferFailed)

            return .none
        }

        state.download = TransferResult(lastSample: last, wasPartial: false)
        guard state.measuresUpload else {
            state.phase = .finished

            return .none
        }

        state.phase = .connecting(.upload)

        return measure(.upload, on: server, token: token)
    }

    /// A download that never started fails over once, to another host if there is one. An offline device, a second
    /// failure or an interruption ends the run.
    func downloadFailed(_ error: any Error, state: inout State) -> Effect<Action> {
        guard let error = SpeedTestError.mapping(error) else {
            return .none
        }
        guard error == .transferFailed, !state.hasFailedOver,
              let failed = state.order.first(where: { $0.server == state.selection?.server }),
              let target = ServerSelector.failoverTarget(after: failed, in: state.order)
        else {
            state.end(with: error)

            return .none
        }

        state.select(target, reason: .failover)
        state.hasFailedOver = true

        return measureDownload(state: state)
    }

    /// One measurement: a `sampled` action per sample, then `transferResponse` when the stream ends.
    private func measure(_ direction: TransferDirection, on server: Server, token: TransferToken) -> Effect<Action> {
        .run { send in
            for try await sample in transferMeter.measure(server, direction, token) {
                await send(.sampled(direction, sample))
            }
            await send(.transferResponse(direction, .success(())))
        } catch: { error, send in
            await send(.transferResponse(direction, .failure(error)))
        }
        .cancellable(id: SpeedTestId())
    }

    /// Going to the background stops a run on iOS only. `.inactive` never does: Control Center and the location
    /// prompt both make the scene inactive.
    func scenePhaseChanged(_ scenePhase: ScenePhase, state: inout State) -> Effect<Action> {
        #if os(iOS)
            guard scenePhase == .background, state.isRunning else {
                return .none
            }

            state.interrupt(.background)

            return .cancel(id: SpeedTestId())
        #else
            return .none
        #endif
    }
}
