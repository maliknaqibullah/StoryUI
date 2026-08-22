import XCTest
import SwiftUI
import UIKit
@testable import StoryUI

/// The touch layer sits in the same ZStack as the reply composer. If its
/// platform view wins hit testing over the composer, the text field never
/// receives the tap and the keyboard never opens — which is exactly the bug
/// this checks for.
final class StoryTouchSurfaceLayoutTests: XCTestCase {

    private struct Harness: View {
        var body: some View {
            ZStack {
                Color.black

                StoryTouchSurface(
                    isEnabled: true,
                    locksPaging: false,
                    onHoldBegan: {},
                    onSessionEnded: {},
                    onTap: { _ in }
                )

                VStack {
                    Spacer()
                    TextField("reply", text: .constant(""))
                        .frame(height: 44)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    func testComposerWinsHitTestingOverTouchLayer() {
        let host = UIHostingController(rootView: Harness())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        // A point on the reply text field.
        let composerPoint = CGPoint(x: 195, y: 844 - 24 - 22)
        let hit = window.hitTest(composerPoint, with: nil)

        XCTAssertNotNil(hit)
        XCTAssertFalse(
            isTouchSurface(hit),
            "the story touch layer swallowed the tap meant for the composer"
        )

        // A point in the middle of the story still belongs to the touch layer.
        let storyPoint = CGPoint(x: 195, y: 300)
        XCTAssertTrue(
            isTouchSurface(window.hitTest(storyPoint, with: nil)),
            "the story touch layer no longer receives taps on the story"
        )
    }

    private func isTouchSurface(_ view: UIView?) -> Bool {
        var candidate = view

        while let current = candidate {
            if current is StoryTouchSurfaceView { return true }
            candidate = current.superview
        }

        return false
    }
}
