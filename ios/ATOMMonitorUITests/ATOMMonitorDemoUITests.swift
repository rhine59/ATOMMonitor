import XCTest

final class ATOMMonitorDemoUITests: XCTestCase {
    func testRecordedFeatureTour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--demo-mode", "--reset-demo-preferences"]
        app.launch()

        step("Map: edge-to-edge station health map loaded from the station snapshot")
        XCTAssertTrue(app.tabBars.buttons["Map"].waitForExistence(timeout: 8))
        sleep(3)

        step("Stations: searchable station registry")
        app.tabBars.buttons["Stations"].tap()
        XCTAssertTrue(app.navigationBars["ATOM Stations"].waitForExistence(timeout: 3))
        sleep(2)

        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 2) {
            search.tap()
            search.typeText("Demo Healthy")
            sleep(2)
            let favourite = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add PW Demo Healthy")).firstMatch
            if favourite.waitForExistence(timeout: 2) { favourite.tap(); sleep(2) }
            let clear = search.buttons["Clear text"]
            if clear.exists { clear.tap() }
        }

        step("Station detail: complete health and technical telemetry")
        let healthy = app.staticTexts["PW Demo Healthy"].firstMatch
        if healthy.waitForExistence(timeout: 3) {
            healthy.tap(); sleep(4)
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        }

        step("Favourites: selected ground stations")
        app.tabBars.buttons["Favourites"].tap(); sleep(3)

        step("Settings: server connection, refresh interval, home station and favourites")
        app.tabBars.buttons["Settings"].tap(); sleep(3)

        let server = app.textFields.firstMatch
        if server.waitForExistence(timeout: 2) {
            server.tap()
            server.press(forDuration: 1)
            if app.menuItems["Select All"].waitForExistence(timeout: 1) { app.menuItems["Select All"].tap() }
            server.typeText("https://atom.example.net/")
            sleep(1)
            let test = app.buttons["Test Connection"]
            if test.exists { test.tap(); sleep(3) }
        }

        step("Settings: automatic data refresh defaults to one minute and supports 1-10 minutes")
        let refreshLabel = app.staticTexts["Refresh interval"]
        if !refreshLabel.exists { app.swipeUp(); sleep(1) }
        if refreshLabel.waitForExistence(timeout: 2) {
            let increment = app.buttons.matching(NSPredicate(format: "label == %@", "Increment")).firstMatch
            if increment.exists { increment.tap(); increment.tap(); sleep(2) }
        }
        app.swipeUp(); sleep(2)

        step("Help: project purpose and user guide")
        app.tabBars.buttons["Help"].tap(); sleep(3)

        step("Map: cached snapshot remains available between automatic refresh cycles")
        app.tabBars.buttons["Map"].tap(); sleep(4)
    }

    private func step(_ text: String) {
        XCTContext.runActivity(named: "DEMO: \(text)") { _ in
            print("ATOM_DEMO_STEP|\(text)")
        }
    }
}
