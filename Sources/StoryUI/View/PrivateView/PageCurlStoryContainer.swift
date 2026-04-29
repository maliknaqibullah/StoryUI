//
//  PageCurlStoryContainer.swift
//  StoryUI
//
//  Created by Malik on 29/04/2026.
//


import SwiftUI

struct PageCurlStoryContainer: View {
    @ObservedObject var viewModel: StoryViewModel
    @Binding var isPresented: Bool
    @Binding var isPaused: Bool

    let userClosure: UserCompletionHandler?
    let onUserChanged: ((String) -> Void)?
    let onDeleteTapped: ((String) -> Void)?
    let myUserID: String?

    @GestureState private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Render adjacent pages for the curl effect
                ForEach(visibleIndices, id: \.self) { i in
                    if let model = viewModel.stories[safe: i] {
                        StoryDetailView(
                            viewModel: viewModel,
                            model: model,
                            isPresented: $isPresented,
                            isPaused: $isPaused,
                            userClosure: userClosure,
                            onUserChanged: onUserChanged,
                            onDeleteTapped: onDeleteTapped,
                            myUserID: myUserID
                        )
                        .frame(width: width, height: height)
                        .offset(x: xOffset(for: i, width: width))
                        .modifier(PageCurlModifier(
                            offset: xOffset(for: i, width: width),
                            width: width
                        ))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                        // Update viewModel in real time for story sync
                        let progress = -value.translation.width / width
                        let targetIndex = (currentIndex + (progress > 0 ? 1 : -1))
                            .clamped(to: 0..<viewModel.stories.count)
                        if abs(progress) > 0.05 {
                            viewModel.currentStoryUser = viewModel.stories[targetIndex].id
                        }
                    }
                    .onEnded { value in
                        let threshold = width * 0.35
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            if value.translation.width < -threshold,
                               currentIndex < viewModel.stories.count - 1 {
                                currentIndex += 1
                            } else if value.translation.width > threshold,
                                      currentIndex > 0 {
                                currentIndex -= 1
                            }
                            viewModel.currentStoryUser = viewModel.stories[currentIndex].id
                        }
                    }
            )
        }
        .onChange(of: viewModel.currentStoryUser) { newUser in
            if let i = viewModel.stories.firstIndex(where: { $0.id == newUser }) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    currentIndex = i
                }
            }
        }
    }

    // Only render current ± 1 page for performance
    private var visibleIndices: [Int] {
        let lo = max(0, currentIndex - 1)
        let hi = min(viewModel.stories.count - 1, currentIndex + 1)
        return Array(lo...hi).reversed() // render current on top
    }

    private func xOffset(for index: Int, width: CGFloat) -> CGFloat {
        let base = CGFloat(index - currentIndex) * width
        return base + dragOffset
    }
}

// MARK: - Page Curl Modifier
struct PageCurlModifier: ViewModifier {
    let offset: CGFloat   // current x offset of this page
    let width: CGFloat

    // progress: -1 (fully left) → 0 (centered) → 1 (fully right)
    private var progress: CGFloat {
        (offset / width).clamped(to: -1...1)
    }

    // Fold angle: pages fold away as they leave center
    private var rotationAngle: Angle {
        Angle(degrees: Double(progress) * 55)
    }

    // Pages fold from their leading/trailing edge
    private var anchor: UnitPoint {
        progress > 0 ? .leading : .trailing
    }

    // Slight scale to simulate perspective depth
    private var scaleEffect: CGFloat {
        1.0 - abs(progress) * 0.08
    }

    // Shadow that appears on the folding edge
    private var shadowOpacity: Double {
        Double(abs(progress)) * 0.45
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                rotationAngle,
                axis: (x: 0, y: 1, z: 0),
                anchor: anchor,
                anchorZ: 0,
                perspective: 0.6        // ← key: low perspective = clean curl, no zoom distortion
            )
            .scaleEffect(scaleEffect)
            .overlay(
                // Fold shadow overlay
                LinearGradient(
                    colors: [
                        Color.black.opacity(shadowOpacity),
                        Color.clear
                    ],
                    startPoint: progress > 0 ? .leading : .trailing,
                    endPoint: progress > 0 ? .trailing : .leading
                )
                .allowsHitTesting(false)
            )
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: offset)
    }
}

// MARK: - Helpers
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
    func clamped(to range: Range<Self>) -> Self {
        min(max(self, range.lowerBound), Swift.max(range.lowerBound, range.upperBound as! Int - 1 as! Self))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
