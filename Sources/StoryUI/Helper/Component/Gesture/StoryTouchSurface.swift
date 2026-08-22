//
//  StoryTouchSurface.swift
//  StoryUI
//
//  Touch handling for the story surface.
//

import SwiftUI
import UIKit

/// Horizontal half of the story surface a tap landed in.
enum StoryTouchZone {
    case leading
    case trailing
}

/// The story's touch layer.
///
/// One view owns every touch on the story surface: the hold that pauses
/// playback, the taps that move between stories and, while the reply composer
/// is open, the lock of the enclosing paging scroll view. Keeping them in one
/// place is what makes the priorities predictable — there is no second gesture
/// recognizer left that can cancel the first one.
///
/// The pause is bound to the touch session, not to the finger staying still: it
/// begins once the finger has been down for `holdDelay` and ends only when the
/// touch itself ends (lift or system cancel). How far the finger travels is
/// only ever used to decide whether the release was a tap, never to resume
/// playback, so an unsteady finger keeps the story paused.
struct StoryTouchSurface: UIViewRepresentable {
    /// Story navigation is off while something else owns the screen.
    var isEnabled: Bool
    /// Locks the paging scroll view this surface lives in, so the story cannot
    /// change while the reply composer is open.
    var locksPaging: Bool
    /// How long the finger has to stay down before the story pauses. Short
    /// enough to feel immediate, long enough that a tap does not flicker.
    var holdDelay: TimeInterval = 0.2
    var onHoldBegan: () -> Void
    var onSessionEnded: () -> Void
    var onTap: (StoryTouchZone) -> Void

    func makeUIView(context: Context) -> StoryTouchSurfaceView {
        let view = StoryTouchSurfaceView()
        view.backgroundColor = .clear
        apply(to: view)
        return view
    }

    func updateUIView(_ view: StoryTouchSurfaceView, context: Context) {
        apply(to: view)
    }

    static func dismantleUIView(_ view: StoryTouchSurfaceView, coordinator: ()) {
        view.locksPaging = false
    }

    private func apply(to view: StoryTouchSurfaceView) {
        view.holdDelay = holdDelay
        view.onHoldBegan = onHoldBegan
        view.onSessionEnded = onSessionEnded
        view.onTap = onTap
        view.isUserInteractionEnabled = isEnabled
        view.locksPaging = locksPaging
    }
}

final class StoryTouchSurfaceView: UIView {

    var holdDelay: TimeInterval = 0.2
    var onHoldBegan: (() -> Void)?
    var onSessionEnded: (() -> Void)?
    var onTap: ((StoryTouchZone) -> Void)?

    /// Movement up to this distance still counts as a tap on release. Above it
    /// the touch was a swipe and belongs to the paging scroll view.
    private let tapMovementTolerance: CGFloat = 12
    /// A touch held longer than this is a hold, so its release navigates
    /// nowhere even if the finger never moved.
    private let tapMaximumDuration: TimeInterval = 0.35

    var locksPaging = false {
        didSet {
            guard locksPaging != oldValue else { return }
            applyPagingLock()
        }
    }

    private weak var lockedScrollView: UIScrollView?
    private var activeTouch: UITouch?
    private var touchStartPoint: CGPoint = .zero
    private var touchStartTime: TimeInterval = 0
    private var holdWorkItem: DispatchWorkItem?

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            // Leaving the hierarchy must not strand a disabled scroll view.
            releasePagingLock()
        } else {
            applyPagingLock()
        }
    }

    deinit {
        holdWorkItem?.cancel()
        lockedScrollView?.isScrollEnabled = true
    }

    // MARK: Touch session

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        // A second finger joins the running session instead of starting one.
        guard activeTouch == nil, let touch = touches.first else { return }

        activeTouch = touch
        touchStartPoint = touch.location(in: self)
        touchStartTime = event?.timestamp ?? CACurrentMediaTime()
        scheduleHold()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        /*
         Deliberately does nothing. Movement decides what a release means, it
         never ends the touch session and therefore never resumes the story.
        */
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        guard let touch = activeTouch, touches.contains(touch) else { return }

        let endPoint = touch.location(in: self)
        let duration = (event?.timestamp ?? CACurrentMediaTime()) - touchStartTime
        let distance = hypot(
            endPoint.x - touchStartPoint.x,
            endPoint.y - touchStartPoint.y
        )

        finishSession()

        guard
            distance <= tapMovementTolerance,
            duration <= tapMaximumDuration
        else { return }

        onTap?(endPoint.x < bounds.width / 2 ? .leading : .trailing)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)

        guard let touch = activeTouch, touches.contains(touch) else { return }

        // The scroll view took the touch over: a swipe, never a tap.
        finishSession()
    }

    private func scheduleHold() {
        holdWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self, self.activeTouch != nil else { return }
            self.onHoldBegan?()
        }

        holdWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay, execute: item)
    }

    /// Ends the touch session exactly once, whatever ended it.
    private func finishSession() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        activeTouch = nil
        onSessionEnded?()
    }

    // MARK: Paging lock

    private func applyPagingLock() {
        guard locksPaging else {
            releasePagingLock()
            return
        }

        guard lockedScrollView == nil, let scrollView = enclosingScrollView() else { return }

        lockedScrollView = scrollView
        scrollView.isScrollEnabled = false
    }

    private func releasePagingLock() {
        lockedScrollView?.isScrollEnabled = true
        lockedScrollView = nil
    }

    private func enclosingScrollView() -> UIScrollView? {
        var candidate: UIView? = superview

        while let current = candidate {
            if let scrollView = current as? UIScrollView { return scrollView }
            candidate = current.superview
        }

        return nil
    }
}
