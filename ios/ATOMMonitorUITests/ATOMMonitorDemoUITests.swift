import XCTest

final class ATOMMonitorDemoUITests: XCTestCase {
    func testRecordedFeatureTour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--demo-mode", "--reset-demo-preferences"]
        app.launch()

        step("Map: edge-to-edge station health map")
        XCTAssertTrue(app.tabBars.buttons["Map"].waitForExistence(timeout: 5))
        sleep(3)

        step("Stations: searchable list and favourites")
        app.tabBars.buttons["Stations"].tap()
        XCTAssertTrue(app.navigationBars["ATOM Stations"].waitForExistence(timeout: 3))
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 2) {
            search.tap(); search.typeText("Demo Healthy"); sleep(2)
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add PW Demo Healthy")).firstMatch.tap()
            sleep(2)
            search.buttons["Clear text"].tap()
        }

        step("Station detail: complete health and technical telemetry")
        let healthy = app.staticTexts["PW Demo Healthy"].firstMatch
        if healthy.waitForExistence(timeout: 3) { healthy.tap(); sleep(4); app.navigationBars.buttons.firstMatch.tap() }

        step("Favourites: durable selected stations")
        app.tabBars.buttons["Favourites"].tap(); sleep(3)

        step("Settings: map home station and configurable server")
        app.tabBars.buttons["Settings"].tap(); sleep(3)
        let server = app.textFields.firstMatch
        if server.waitForExistence(timeout: 2) {
            server.tap(); server.press(forDuration: 1); app.menuItems["Select All"].tap(); server.typeText("https://atom.example.net/")
            app.buttons["Test Connection"].tap(); sleep(3)
        }
        app.swipeUp(); sleep(2)

        step("Help: project purpose and user guide")
        app.tabBars.buttons["Help"].tap(); sleep(3)

        step("Map: return to live station overview")
        app.tabBars.buttons["Map"].tap(); sleep(4)
    }

    private func step(_ text: String) {
        XCTContext.runActivity(named: "DEMO: \(text)") { _ in
            print("ATOM_DEMO_STEP|\(text)")
        }
    }
}
