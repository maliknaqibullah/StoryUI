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
/// One recognizer owns every touch on the story surface: the hold that pauses
/// playback and the taps that move between stories. Keeping them together is
/// what makes the priorities predictable — there is no second gesture left
/// that can cancel the first one.
///
/// The pause is bound to the touch session, not to the finger staying still: it
/// begins once the finger has been down for `holdDelay` and ends only when the
/// finger actually leaves the screen. This is why it is a gesture recognizer
/// and not a `UIView` with `touchesBegan`: as soon as the enclosing paging
/// scroll view starts panning it cancels touch delivery to *views*, so a view
/// based implementation sees a cancel after a few points of movement and
/// resumes the story under the user's thumb. A recognizer keeps receiving the
/// same touch until it really ends, so a shaky finger — and even a full swipe —
/// keeps the story paused until release.
struct StoryTouchSurface: UIViewRepresentable {
    /// Story navigation is off while something else owns the screen.
    var isEnabled: Bool
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

    private func apply(to view: StoryTouchSurfaceView) {
        view.holdDelay = holdDelay
        view.onHoldBegan = onHoldBegan
        view.onSessionEnded = onSessionEnded
        view.onTap = onTap
        view.isTrackingEnabled = isEnabled
    }
}

final class StoryTouchSurfaceView: UIView {

    var holdDelay: TimeInterval = 0.2 {
        didSet { recognizer.holdDelay = holdDelay }
    }
    var onHoldBegan: (() -> Void)? {
        didSet { recognizer.onHoldBegan = onHoldBegan }
    }
    var onSessionEnded: (() -> Void)? {
        didSet { recognizer.onSessionEnded = onSessionEnded }
    }
    var onTap: ((StoryTouchZone) -> Void)? {
        didSet { recognizer.onTap = onTap }
    }

    var isTrackingEnabled = true {
        didSet { recognizer.isEnabled = isTrackingEnabled }
    }

    private let recognizer = StoryTouchSessionRecognizer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(recognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

/// Reports the raw touch session on the story surface.
///
/// The recognizer never claims the touch (it stays in `.possible` and fails at
/// the end), so it changes nothing about the gestures around it: paging still
/// pages, buttons above it still receive their taps.
private final class StoryTouchSessionRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {

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

    private var activeTouch: UITouch?
    private var startPoint: CGPoint = .zero
    private var startTime: TimeInterval = 0
    private var holdWorkItem: DispatchWorkItem?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = self
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    convenience init() {
        self.init(target: nil, action: nil)
    }

    deinit {
        holdWorkItem?.cancel()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        // A second finger joins the running session instead of starting one.
        guard activeTouch == nil, let touch = touches.first else { return }

        activeTouch = touch
        startPoint = touch.location(in: view)
        startTime = event.timestamp
        scheduleHold()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        /*
         Deliberately does nothing. Movement decides what a release means, it
         never ends the touch session and therefore never resumes the story.
        */
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        guard let touch = activeTouch, touches.contains(touch) else { return }

        let endPoint = touch.location(in: view)
        let duration = event.timestamp - startTime
        let distance = hypot(
            endPoint.x - startPoint.x,
            endPoint.y - startPoint.y
        )
        let width = view?.bounds.width ?? 0

        finishSession()

        guard
            distance <= tapMovementTolerance,
            duration <= tapMaximumDuration,
            width > 0
        else { return }

        onTap?(endPoint.x < width / 2 ? .leading : .trailing)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)

        guard let touch = activeTouch, touches.contains(touch) else { return }

        // Only a real cancel of the touch itself gets here, never the scroll
        // view merely taking over the pan.
        finishSession()
    }

    override func reset() {
        super.reset()

        guard activeTouch != nil else { return }

        // Safety net: the session may never outlive the recognizer's own cycle.
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
        state = .failed
        onSessionEnded?()
    }

    // MARK: UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Observing touches must never compete with paging or with any gesture
        // the host attaches (pull down to dismiss).
        true
    }
}
