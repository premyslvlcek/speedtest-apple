//
//  SpeedTestUITests.swift
//  SpeedTestUITests
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import XCTest

/// A smoke test of the real app against the scripted run. It checks only what no package test can: that the app
/// target is wired together. What a run does (Stop, failures, the text on screen) is pinned in the package tests.
final class SpeedTestUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A run fills the brief's three fields and shows the address, and the app's database keeps it in the history.
    @MainActor
    func testARunFillsTheScreenAndLandsInTheHistory() {
        let app = XCUIApplication()
        // English, so "Run again" reads the same on every machine; elements are found by identifier.
        app.launchArguments = ["-scriptedRun", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let button = app.buttons["startStopButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(button.wait(for: \.label, toEqual: "Run again", timeout: 20), "the run never finished")

        let server = app.staticTexts["serverField"].label
        XCTAssertFalse(server.contains("—") || server.contains("choosing"), "no server: \(server)")
        XCTAssertTrue(app.staticTexts["pingField"].label.contains(" ms"))
        XCTAssertTrue(app.staticTexts["downloadField"].label.contains("Mbps"))
        // The scripted directory's documentation address: proves the launch ran on the scripted clients.
        XCTAssertTrue(app.staticTexts["ipField"].label.contains("203.0.113.7"))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Finished run"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["historyButton"].tap()
        // A history row, not a cell of the main list behind the sheet. The history is in memory, so it's this run's.
        let row = app.staticTexts["historyRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the finished run isn't in the history")
        XCTAssertTrue(row.label.contains("203.0.113.7"), "unexpected row: \(row.label)")
    }
}
