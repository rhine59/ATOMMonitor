import XCTest

final class ATOMMonitorDemoUITests: XCTestCase {
    func testRecordedFeatureTour() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--demo-mode", "--reset-demo-preferences"]
        app.launch()

        step("Map: station health, update state, refresh and map layers")
        selectTab("Map", in: app)
        let mapRefresh = refreshButton(in: app)
        XCTAssertTrue(mapRefresh.waitForExistence(timeout: 4), "Missing Map refresh control")
        sleep(2); mapRefresh.tap(); sleep(2)
        let layers = app.buttons["Map layers"]
        XCTAssertTrue(layers.waitForExistence(timeout: 3))
        for layer in ["Satellite + Labels", "Satellite", "Standard"] {
            layers.tap()
            XCTAssertTrue(app.buttons[layer].waitForExistence(timeout: 2), "Missing map layer \(layer)")
            app.buttons[layer].tap(); sleep(2)
        }

        step("Map: Home explains that no Home station is configured")
        let home = app.buttons["Go to home station"]
        XCTAssertTrue(home.waitForExistence(timeout: 3))
        home.tap()
        XCTAssertTrue(app.staticTexts["No home station set"].waitForExistence(timeout: 3))
        app.buttons["OK"].tap(); sleep(1)

        step("Stations: search, refresh, pull-to-refresh, favourite and detail")
        selectTab("Stations", in: app)
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 3))
        refreshButton(in: app).tap(); sleep(2)
        let list = app.tables.firstMatch
        if list.waitForExistence(timeout: 2) {
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                .press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
            sleep(2)
        }
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("Demo Healthy"); sleep(1)
        let favourite = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Add PW Demo Healthy")).firstMatch
        if favourite.waitForExistence(timeout: 2) { favourite.tap() }
        let healthy = app.staticTexts["PW Demo Healthy"].firstMatch
        if healthy.waitForExistence(timeout: 3) {
            healthy.tap(); sleep(3)
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
        }
        if search.exists { let clear = search.buttons["Clear text"]; if clear.exists { clear.tap() } }

        step("Favourites: locally persisted favourite station")
        selectTab("Favourites", in: app); sleep(2)
        XCTAssertTrue(app.staticTexts["PW Demo Healthy"].waitForExistence(timeout: 3))

        step("Report: summaries and category drill-down into Stations")
        selectTab("Report", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["Report"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Total stations"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["PilotAware versions"].waitForExistence(timeout: 2))
        let healthyReport = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Healthy")).firstMatch
        XCTAssertTrue(healthyReport.waitForExistence(timeout: 2))
        healthyReport.tap(); sleep(2)
        XCTAssertTrue(app.navigationBars["Stations"].waitForExistence(timeout: 3))

        step("Report: generate HTML/CSV and open the native share sheet")
        selectTab("Report", in: app); sleep(1)
        let share = app.buttons["Share report"]
        XCTAssertTrue(share.waitForExistence(timeout: 2))
        share.tap(); sleep(3)
        let close = app.buttons["Close"].firstMatch
        if close.exists { close.tap() } else { app.swipeDown() }
        sleep(2)

        step("Settings: server, refresh, inactivity and back-level highlighting")
        selectTab("Settings", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Test Connection"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Every ")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Inactive after ")).firstMatch.waitForExistence(timeout: 2))
        let backLevel = app.switches["Highlight back-level software"]
        XCTAssertTrue(backLevel.waitForExistence(timeout: 2))
        if (backLevel.value as? String) != "1" { backLevel.tap() }
        sleep(1)

        step("More and Legend: alphabetic utilities and current icon meanings")
        openMore(in: app)
        for name in ["About", "Admin", "Feedback", "Help", "Legend", "Settings"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 2), "Missing \(name) in More")
        }
        app.staticTexts["Legend"].tap(); sleep(2)
        XCTAssertTrue(app.navigationBars["Station Icon Legend"].waitForExistence(timeout: 3))
        for name in ["Healthy", "Warning", "No recent heartbeat", "Inactive", "Unknown", "Back-level software"] {
            XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 2), "Missing legend item \(name)")
        }

        step("Admin: complete service inventory and guarded API scaling")
        selectTab("Admin", in: app); sleep(3)
        XCTAssertTrue(app.navigationBars["Admin"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["API service"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["atommonitor-admin-monitor"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["atommonitor-admin-control"].waitForExistence(timeout: 3))
        let stepper = app.steppers.firstMatch
        XCTAssertTrue(stepper.waitForExistence(timeout: 2))
        stepper.buttons["Increment"].tap(); sleep(1)
        app.buttons["Apply change"].tap()
        XCTAssertTrue(app.buttons["Apply 3 replicas"].waitForExistence(timeout: 2))
        app.buttons["Apply 3 replicas"].tap()
        XCTAssertTrue(app.staticTexts["Demo scale complete: 3 healthy replicas"].waitForExistence(timeout: 5))
        sleep(2)

        step("Help: embedded user guide and privacy boundary")
        selectTab("Help", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["User Guide"].waitForExistence(timeout: 3))

        step("Feedback: rating, comments and private submission controls")
        selectTab("Feedback", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["Feedback"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your rating"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Comments or suggestions"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Send Feedback"].waitForExistence(timeout: 2))

        step("About: version, build, credits, licensing and privacy")
        selectTab("About", in: app); sleep(2)
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Version"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Build"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Richard Hine")).firstMatch.waitForExistence(timeout: 2))
        app.swipeUp(); sleep(1)
        XCTAssertTrue(app.staticTexts["Licence & distribution"].waitForExistence(timeout: 2))

        step("Map: return to the primary operational view")
        selectTab("Map", in: app); sleep(3)
    }

    private func openMore(in app: XCUIApplication) {
        let more = app.tabBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 2), "Missing More tab")
        more.tap()
    }

    private func selectTab(_ name: String, in app: XCUIApplication) {
        let direct = app.tabBars.buttons[name]
        if direct.waitForExistence(timeout: 1) {
            direct.tap()
            return
        }
        openMore(in: app)
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
