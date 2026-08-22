import XCTest
import SwiftUI
import UIKit
@testable import StoryUI

/// Mounts the real story viewer and checks that the reply field can take — and
/// keep — first responder. A focus that is handed back within the next runloop
/// turns is what the user sees as "the keyboard never opens".
final class StoryComposerFocusTests: XCTestCase {

    private func makeModels() -> [StoryUIModel] {
        let story = Story(
            id: "story-1",
            mediaURL: "https://example.invalid/story.jpg",
            config: StoryConfiguration(
                storyType: .message(
                    config: StoryInteractionConfig(showLikeButton: true),
                    emojis: nil,
                    placeholder: "Reply"
                ),
                mediaType: .image
            )
        )

        return [
            StoryUIModel(
                id: "author-1",
                user: StoryUIUser(id: "author-1", name: "Someone", image: ""),
                stories: [story]
            )
        ]
    }

    private func mount() -> (UIWindow, UIHostingController<StoryView>) {
        let host = UIHostingController(
            rootView: StoryView(
                stories: makeModels(),
                isPresented: .constant(true),
                myUserID: "me"
            )
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        spinRunLoop(for: 0.5)

        return (window, host)
    }

    private func spinRunLoop(for interval: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }

    private func firstTextField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField { return field }

        for subview in view.subviews {
            if let found = firstTextField(in: subview) { return found }
        }

        return nil
    }

    func testReplyFieldKeepsFirstResponder() throws {
        let (window, _) = mount()

        let field = try XCTUnwrap(
            firstTextField(in: window),
            "the reply field is not in the view hierarchy"
        )

        XCTAssertTrue(field.becomeFirstResponder(), "the reply field refused focus")

        // Everything the focus triggers (composer state, paging lock, story
        // updates) has to settle without taking the focus away again.
        spinRunLoop(for: 1.5)

        XCTAssertTrue(
            field.isFirstResponder,
            "focus was taken away from the reply field after it was granted"
        )
    }

    /// The real app path: focus opens the keyboard, the keyboard notification
    /// flips the composer state, and that state locks paging. None of it may
    /// hand the focus back.
    func testKeyboardNotificationDoesNotStealFocus() throws {
        let (window, _) = mount()

        let field = try XCTUnwrap(firstTextField(in: window))
        XCTAssertTrue(field.becomeFirstResponder())

        NotificationCenter.default.post(
            name: UIResponder.keyboardWillShowNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: NSValue(
                    cgRect: CGRect(x: 0, y: 508, width: 390, height: 336)
                )
            ]
        )

        spinRunLoop(for: 1.5)

        // The lock has to have happened, otherwise this test proves nothing.
        XCTAssertTrue(
            scrollViews(in: window).contains { !$0.isScrollEnabled },
            "paging was never locked, so this test did not exercise the lock"
        )

        XCTAssertTrue(
            field.isFirstResponder,
            "the composer state that follows the keyboard took the focus away"
        )
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []

        if let scrollView = view as? UIScrollView { found.append(scrollView) }
        for subview in view.subviews { found.append(contentsOf: scrollViews(in: subview)) }

        return found
    }

    func testComposerPointIsNotCoveredByTouchLayer() throws {
        let (window, _) = mount()

        let field = try XCTUnwrap(firstTextField(in: window))
        let point = field.superview?.convert(field.center, to: window) ?? .zero
        let hit = window.hitTest(point, with: nil)

        var candidate = hit
        var hitsTouchLayer = false

        while let current = candidate {
            if current is StoryTouchSurfaceView { hitsTouchLayer = true }
            candidate = current.superview
        }

        XCTAssertFalse(
            hitsTouchLayer,
            "the story touch layer covers the reply field"
        )
        XCTAssertTrue(
            hit === field || hit?.isDescendant(of: field) == true,
            "a tap on the reply field lands on \(String(describing: hit))"
        )
    }
}
