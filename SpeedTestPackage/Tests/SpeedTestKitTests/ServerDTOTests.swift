//
//  ServerDTOTests.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import Testing

@testable import SpeedTestKit

@Suite struct ServerDTOTests {
    @Test func decodesTheRealDirectoryAnswer() throws {
        let servers = try ServerDTO.servers(from: Fixture.data("servers"))

        // All nine entries are usable, so a filter that dropped a valid server would show here.
        #expect(servers.count == 9)

        let first = try #require(servers.first)
        #expect(first.provider == "jablonka.cz")
        #expect(first.city == "Prague")
        #expect(first.url.port == 80)
        #expect(first.coordinate == Coordinate(latitude: 50.08000183105469, longitude: 14.420000076293945))
    }

    @Test func keepsTheSameHostOnBothPorts() throws {
        // One wifiman.me name is listed on :81 and :88, with different cities.
        let servers = try ServerDTO.servers(from: Fixture.data("servers"))

        let shared = servers.filter { $0.host.hasPrefix("zwedgsvak0ky6ulf0ta") }

        #expect(shared.map(\.url.port) == [81, 88])
        #expect(shared.map(\.city) == ["Nove Mesto nad Metuji", "Prague"])
    }

    @Test func keepsOnlyTheUsableEntries() throws {
        // servers-mixed.json, in order: Alpha (usable), an entry without `city`, a `null` latitude, a plain `http`
        // URL, Alpha's URL again, a `null` element, an `https` host that only looks like wifiman.me, Beta (usable). One bad entry
        // must not cost the whole list.
        let servers = try ServerDTO.servers(from: Fixture.data("servers-mixed"))

        #expect(servers.map(\.provider) == ["Alpha", "Beta"])
    }
}
