//
//  RecessEyesUITestsLaunchTests.swift
//  RecessEyesUITests
//
//  Created by Антон Коренской on 18.02.2026.
//

import XCTest

final class RecessEyesUITestsLaunchTests: XCTestCase {

    // Disabled: when true, Xcode's multi-config runner toggles the OS-wide
    // AppleInterfaceStyle (Light/Dark) between configurations and does not
    // restore it on completion. Restoring from within the test runner is
    // unreliable — the runner's spawned `defaults` and CFPreferences writes
    // fail to propagate (the toggle is performed through a private mechanism
    // that bypasses cfprefsd), so the system theme remains stuck on whichever
    // config ran last. With this flag off, the test launches once and the
    // user's appearance is untouched.
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
