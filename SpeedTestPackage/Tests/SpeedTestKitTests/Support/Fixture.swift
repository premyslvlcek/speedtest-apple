//
//  Fixture.swift
//  SpeedTestKitTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation
import Testing

enum Fixture {
    /// A JSON file from `Tests/SpeedTestKitTests/Fixtures`, which the manifest copies into the test bundle as is.
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}
