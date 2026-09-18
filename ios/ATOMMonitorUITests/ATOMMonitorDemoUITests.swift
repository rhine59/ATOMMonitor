import XCTest

final class ATOMMonitorDemoUITests: XCTestCase {
    func testRecordedFeatureTour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--demo-mode", "--reset-demo-preferences"]
        app.launch()

        step("Map: edge-to-edge station health map, last-updated time and manual refresh")
        selectTab("Map", in: app)
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
        selectTab("Stations", in: app)
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 3), "Stations screen did not become interactive")
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
        selectTab("Favourites", in: app); sleep(2)

        step("Report: station status and PilotAware-version summary")
        selectTab("Report", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["Report"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Total stations"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["PilotAware versions"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Share report"].waitForExistence(timeout: 2))

        step("Settings: server, refresh interval and inactive threshold")
        selectTab("Settings", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Test Connection"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Every ")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Inactive after ")).firstMatch.waitForExistence(timeout: 2))

        step("Help: project purpose and user guide")
        selectTab("Help", in: app); sleep(2)

        step("Feedback: rating and comments UI without sending mail")
        selectTab("Feedback", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["Feedback"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your rating"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Comments or suggestions"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Send Feedback"].waitForExistence(timeout: 2))

        step("About: identity, version, build, credits and distribution details")
        selectTab("About", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Version"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Build"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Version / Build"].exists, "Combined Version / Build row must not reappear")
        let creator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Richard Hine")).firstMatch
        XCTAssertTrue(creator.waitForExistence(timeout: 2), "Missing Richard Hine creator credit")
        let pilotAware = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "PilotAware ATOM")).firstMatch
        XCTAssertTrue(pilotAware.waitForExistence(timeout: 2), "Missing PilotAware ATOM credit/link")
        app.swipeUp(); sleep(1)
        XCTAssertTrue(app.staticTexts["Licence & distribution"].waitForExistence(timeout: 2))

        step("Map: cached snapshot, persisted layer and last-updated indicator remain available")
        selectTab("Map", in: app); sleep(3)
    }

    private func selectTab(_ name: String, in app: XCUIApplication) {
        let direct = app.tabBars.buttons[name]
        if direct.waitForExistence(timeout: 1) {
            direct.tap()
            return
        }

        let more = app.tabBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 2), "Missing tab '\(name)' and More tab")
        more.tap()

        let destination = app.staticTexts[name].firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 3), "Missing '\(name)' in More")
        destination.tap()
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
