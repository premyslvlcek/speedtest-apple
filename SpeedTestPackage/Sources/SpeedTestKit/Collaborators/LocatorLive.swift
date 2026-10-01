//
//  LocatorLive.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import CoreLocation
import Dependencies
import Foundation

public extension Locator {
    /// Asks for permission on the first call and waits for the user's answer with no timeout.
    /// The timeout starts only once permission is granted, then one coarse fix is requested.
    /// The timeout runs on the registered `continuousClock`, resolved when this value is created.
    static var live: Locator {
        @Dependency(\.continuousClock) var clock
        return Locator(locate: { timeout in
            let request = await LocationRequest(clock: clock)
            return await request.run(timeout: timeout)
        })
    }
}

/// What an authorization status means for a location request. Pure, so it can be tested per platform.
enum AuthorizationDecision: Sendable, Equatable {
    case askUser
    case granted
    case notAuthorized

    static func decision(for status: CLAuthorizationStatus) -> AuthorizationDecision {
        switch status {
        case .notDetermined:
            .askUser

        #if os(iOS)
            case .authorizedAlways, .authorizedWhenInUse:
                .granted
        #else
            // `.authorizedWhenInUse` doesn't exist on native macOS; a granted Mac app is `.authorizedAlways`.
            case .authorizedAlways:
                .granted
        #endif

        case .denied, .restricted:
            .notAuthorized

        @unknown default:
            .notAuthorized
        }
    }
}

/// One location request. Core Location calls the delegate on the thread that created the manager,
/// which is the main thread here, because the whole class is main-actor isolated.
@MainActor
final class LocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private let clock: any Clock<Duration>
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<LocationOutcome, Never>?
    private var timeoutTask: Task<Void, Never>?

    init(clock: any Clock<Duration>) {
        manager = CLLocationManager()
        self.clock = clock
        super.init()
    }

    func run(timeout: Duration) async -> LocationOutcome {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        let outcome: LocationOutcome = switch await AuthorizationDecision.decision(for: authorizationStatus()) {
        case .granted:
            await location(timeout: timeout)

        case .notAuthorized:
            .notAuthorized

        case .askUser:
            // Only reached when the waiting task was cancelled before the user answered.
            .unavailable
        }

        manager.delegate = nil
        return outcome
    }

    // MARK: - Delegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else {
            return
        }

        MainActor.assumeIsolated {
            resumeAuthorization(with: status)
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else {
            return
        }

        let coordinate = Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        MainActor.assumeIsolated {
            resumeLocation(with: .located(coordinate))
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError _: any Error) {
        MainActor.assumeIsolated {
            resumeLocation(with: .unavailable)
        }
    }
}

private extension LocationRequest {
    /// Returns at once if the user has already answered; otherwise asks and waits, with no timeout.
    func authorizationStatus() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        guard current == .notDetermined else {
            return current
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        } onCancel: {
            Task { @MainActor in
                self.resumeAuthorization(with: .notDetermined)
            }
        }
    }

    /// One coarse fix, or `.unavailable` after `timeout`, an error, or cancellation.
    func location(timeout: Duration) async -> LocationOutcome {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                locationContinuation = continuation
                manager.requestLocation()
                timeoutTask = Task { [weak self, clock] in
                    do {
                        try await clock.sleep(for: timeout)
                    } catch {
                        return
                    }
                    self?.resumeLocation(with: .unavailable)
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.resumeLocation(with: .unavailable)
            }
        }
    }

    func resumeAuthorization(with status: CLAuthorizationStatus) {
        guard let continuation = authorizationContinuation else {
            return
        }

        authorizationContinuation = nil
        continuation.resume(returning: status)
    }

    func resumeLocation(with outcome: LocationOutcome) {
        guard let continuation = locationContinuation else {
            return
        }

        locationContinuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        continuation.resume(returning: outcome)
    }
}
