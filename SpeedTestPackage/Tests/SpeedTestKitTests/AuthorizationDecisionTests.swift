//
//  AuthorizationDecisionTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import CoreLocation
import Testing

@testable import SpeedTestKit

@Suite struct AuthorizationDecisionTests {
    @Test(arguments: zip(
        [CLAuthorizationStatus.notDetermined, .authorizedAlways, .denied],
        [AuthorizationDecision.askUser, .granted, .notAuthorized]
    ))
    func decision(status: CLAuthorizationStatus, expected: AuthorizationDecision) {
        #expect(AuthorizationDecision.decision(for: status) == expected)
    }

    #if os(iOS)
        @Test func whenInUseIsGrantedOnIOS() {
            #expect(AuthorizationDecision.decision(for: .authorizedWhenInUse) == .granted)
        }
    #endif
}
