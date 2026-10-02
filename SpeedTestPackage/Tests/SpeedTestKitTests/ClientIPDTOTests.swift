//
//  ClientIPDTOTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import Foundation
import Testing

@testable import SpeedTestKit

@Suite struct ClientIPDTOTests {
    @Test func anEmptyProviderCountsAsUnknown() throws {
        let data = Data(#"{"ip":"2001:db8::7","isp":""}"#.utf8)

        let clientIP = try JSONDecoder().decode(ClientIPDTO.self, from: data).toDomainModel()

        #expect(clientIP == ClientIP(address: "2001:db8::7", provider: nil))
    }
}
