//
//  KnotApp_macOSUITestsLaunchTests.swift
//  KnotApp-macOSUITests
//
//  Created by aa123 on 2026/3/19.
//  Copyright © 2026 Lojii. All rights reserved.
//

import XCTest

final class KnotApp_macOSUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
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
