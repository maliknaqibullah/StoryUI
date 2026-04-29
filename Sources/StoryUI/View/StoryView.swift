//
//  StoryView.swift
//  StoryUI (iOS)
//
//  Created by Naqibullah Malikzada on 28.04.2022.
//

import SwiftUI
import AVFoundation

public struct StoryView: View {
    
    @StateObject private var viewModel = StoryViewModel()
    @Binding private var isPresented: Bool
    @Binding private var isPaused: Bool

    private var stories: [StoryUIModel]
    private var selectedIndex: Int
    let userClosure: UserCompletionHandler?
    let onUserChanged: ((String) -> Void)?
    let onDeleteTapped: ((String) -> Void)?
    let myUserID: String?

    public init(
        stories: [StoryUIModel],
        selectedIndex: Int = 0,
        isPresented: Binding<Bool>,
        isPaused: Binding<Bool> = .constant(false),
        userClosure: UserCompletionHandler? = nil,
        onUserChanged: ((String) -> Void)? = nil,
        onDeleteTapped: ((String) -> Void)? = nil,
        myUserID: String? = nil
    ) {
        self.stories = stories
        self.selectedIndex = selectedIndex
        self._isPresented = isPresented
        self._isPaused = isPaused
        self.userClosure = userClosure
        self.onUserChanged = onUserChanged
        self.onDeleteTapped = onDeleteTapped
        self.myUserID = myUserID
    }
    public var body: some View {
        if isPresented {
            ZStack {
                Color.black.ignoresSafeArea()
                // ← Replace TabView with this:
                PageCurlStoryContainer(
                    viewModel: viewModel,
                    isPresented: $isPresented,
                    isPaused: $isPaused,
                    userClosure: userClosure,
                    onUserChanged: onUserChanged,
                    onDeleteTapped: onDeleteTapped,
                    myUserID: myUserID
                )
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                startStory()
                onUserChanged?(stories[selectedIndex < stories.count ? selectedIndex : 0].id)
            }
            .onDisappear {
                stopVideo()
            }
        }
    }
    
    private func startStory() {
        guard !stories.isEmpty else { return }
        viewModel.stories = stories
        let index = stories.indices.contains(selectedIndex) ? selectedIndex : .zero
        let storyUser = stories[index]
        viewModel.currentStoryUser = storyUser.id
        if !storyUser.stories.isEmpty {
            viewModel.stories[index].isSeen = true
        }
    }

    private func stopVideo() {
        NotificationCenter.default.post(name: .stopVideo, object: nil)
        NotificationCenter.default.removeObserver(self)
    }
}
