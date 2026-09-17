import XCTest

final class ATOMMonitorDemoUITests: XCTestCase {
    func testRecordedFeatureTour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--demo-mode", "--reset-demo-preferences"]
        app.launch()

        step("Map: edge-to-edge station health map, last-updated time and manual refresh")
        XCTAssertTrue(app.tabBars.buttons["Map"].waitForExistence(timeout: 8))
        let mapRefresh = refreshButton(in: app)
        XCTAssertTrue(mapRefresh.waitForExistence(timeout: 3), "Missing Map refresh control")
        sleep(2)
        mapRefresh.tap()
        sleep(2)

        step("Map: choose Standard, Satellite + Labels and Satellite layers")
        let layers = app.buttons["Map layers"]
        XCTAssertTrue(layers.waitForExistence(timeout: 3))
        for layer in ["Satellite + Labels", "Satellite", "Standard"] {
            layers.tap()
            XCTAssertTrue(app.buttons[layer].waitForExistence(timeout: 2), "Missing map layer \(layer)")
            app.buttons[layer].tap()
            sleep(2)
        }

        step("Map: home button reports when no home station is set")
        let home = app.buttons["Go to home station"]
        XCTAssertTrue(home.waitForExistence(timeout: 3))
        home.tap()
        XCTAssertTrue(app.staticTexts["No home station set"].waitForExistence(timeout: 3))
        app.buttons["OK"].tap()
        sleep(1)

        step("Stations: searchable station registry, manual refresh and pull-to-refresh")
        app.tabBars.buttons["Stations"].tap()
        XCTAssertTrue(app.navigationBars["Stations"].waitForExistence(timeout: 3))
        let listRefresh = refreshButton(in: app)
        XCTAssertTrue(listRefresh.waitForExistence(timeout: 2), "Missing Stations refresh control")
        listRefresh.tap(); sleep(2)
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 2) {
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            start.press(forDuration: 0.1, thenDragTo: end); sleep(2)
        }

        step("Stations: search, favourite and inspect complete station telemetry")
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 2) {
            search.tap(); search.typeText("Demo Healthy"); sleep(1)
            let favourite = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add PW Demo Healthy")).firstMatch
            if favourite.waitForExistence(timeout: 2) { favourite.tap() }
            let clear = search.buttons["Clear text"]; if clear.exists { clear.tap() }
        }
        let healthy = app.staticTexts["PW Demo Healthy"].firstMatch
        if healthy.waitForExistence(timeout: 3) { healthy.tap(); sleep(3); if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() } }

        step("Favourites: selected ground stations")
        app.tabBars.buttons["Favourites"].tap(); sleep(2)

        step("Report: station status and PilotAware-version summary")
        app.tabBars.buttons["Report"].tap(); sleep(2)
        XCTAssertTrue(app.navigationBars["Report"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Total stations"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["PilotAware versions"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Share report"].waitForExistence(timeout: 2))

        step("Settings: set a home station and verify the Map home button")
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let homePicker = app.buttons["Home station"]
        if homePicker.waitForExistence(timeout: 2) {
            homePicker.tap()
            let demoHome = app.buttons["PW Demo Healthy"]
            if demoHome.waitForExistence(timeout: 2) { demoHome.tap() }
        }
        app.tabBars.buttons["Map"].tap(); sleep(2)
        XCTAssertTrue(app.buttons["Go to home station"].waitForExistence(timeout: 2))
        app.buttons["Go to home station"].tap(); sleep(2)

        step("Settings: server connection and configurable 1-10 minute refresh interval")
        app.tabBars.buttons["Settings"].tap(); sleep(2)
        let refreshLabel = app.staticTexts["Refresh interval"]
        if !refreshLabel.exists { app.swipeUp(); sleep(1) }
        XCTAssertTrue(refreshLabel.waitForExistence(timeout: 2))
        let increment = app.buttons.matching(NSPredicate(format: "label == %@", "Increment")).firstMatch
        if increment.exists { increment.tap(); increment.tap(); sleep(1) }

        step("Help: project purpose and user guide")
        app.tabBars.buttons["Help"].tap(); sleep(2)

        step("Map: cached snapshot, persisted layer and last-updated indicator remain available")
        app.tabBars.buttons["Map"].tap(); sleep(3)
    }

    private func refreshButton(in app: XCUIApplication) -> XCUIElement {
        let labelled = app.buttons["Refresh stations"]
        if labelled.exists { return labelled.firstMatch }
        return app.buttons.matching(NSPredicate(format: "label == %@ OR identifier == %@", "Refresh", "Refresh")).firstMatch
    }

    private func step(_ text: String) {
        XCTContext.runActivity(named: "DEMO: \(text)") { _ in print("ATOM_DEMO_STEP|\(text)") }
    }
}
