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
    let onAvatarTapped: ((String) -> Void)?
    let onDeleteTapped: ((String) -> Void)?
    /// The "..." header button was tapped, carrying the id of the story that is
    /// visible right now. Only shown when `showsMenuButton` is true.
    let onMenuTapped: ((String) -> Void)?
    let showsMenuButton: Bool
    /// Shows the standalone trash button on an own story. Off for hosts that
    /// offer deletion inside their own "..." menu instead.
    let showsDeleteButton: Bool
    /// Shows the standalone close button. Off for hosts that dismiss the viewer
    /// with the pull down gesture alone.
    let showsCloseButton: Bool
    /// Called once per story, when that story is actually rendered on screen.
    /// Parameters: the user (model) id, then the story id.
    let onStoryDisplayed: ((String, String) -> Void)?
    let myUserID: String?
    public init(
        stories: [StoryUIModel],
        selectedIndex: Int = 0,
        isPresented: Binding<Bool>,
        isPaused: Binding<Bool> = .constant(false),
        userClosure: UserCompletionHandler? = nil,
        onUserChanged: ((String) -> Void)? = nil,
        onAvatarTapped: ((String) -> Void)? = nil,
        onDeleteTapped: ((String) -> Void)? = nil,
        onMenuTapped: ((String) -> Void)? = nil,
        showsMenuButton: Bool = false,
        showsDeleteButton: Bool = true,
        showsCloseButton: Bool = true,
        onStoryDisplayed: ((String, String) -> Void)? = nil,
        myUserID: String? = nil
    ) {
        self.stories = stories
        self.selectedIndex = selectedIndex
        self._isPresented = isPresented
        self._isPaused = isPaused
        self.userClosure = userClosure
        self.onUserChanged = onUserChanged
        self.onAvatarTapped = onAvatarTapped
        self.onDeleteTapped = onDeleteTapped
        self.onMenuTapped = onMenuTapped
        self.showsMenuButton = showsMenuButton
        self.showsDeleteButton = showsDeleteButton
        self.showsCloseButton = showsCloseButton
        self.onStoryDisplayed = onStoryDisplayed
        self.myUserID = myUserID
    }
    public var body: some View {
        if isPresented {
            ZStack {
                Color.black.ignoresSafeArea()
                TabView(selection: $viewModel.currentStoryUser) {
                    ForEach(viewModel.stories) { model in
                        StoryDetailView(
                            viewModel: viewModel,
                            model: model,
                            isPresented: $isPresented,
                            isPaused: $isPaused,
                            userClosure: userClosure,
                            onUserChanged: onUserChanged,
                            onAvatarTapped: onAvatarTapped,
                            onDeleteTapped: onDeleteTapped,
                            onMenuTapped: onMenuTapped,
                            showsMenuButton: showsMenuButton,
                            showsDeleteButton: showsDeleteButton,
                            showsCloseButton: showsCloseButton,
                            onStoryDisplayed: onStoryDisplayed,
                            myUserID: myUserID
                        )
                        .tag(model.id)
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                startStory()
            }
            .onChange(of: stories) { _ in
                updateStoriesFromParent()
            }
            .onDisappear {
                stopVideo()
            }
        }
    }
    
    private func startStory() {
        guard !stories.isEmpty else { return }
        let index = stories.indices.contains(selectedIndex) ? selectedIndex : 0
        let storyUser = stories[index]
        viewModel.stories = stories
        viewModel.currentStoryUser = storyUser.id
        if !storyUser.stories.isEmpty {
            viewModel.stories[index].isSeen = true
        }
        onUserChanged?(storyUser.id)
    }
    private func updateStoriesFromParent() {
        let currentUserID = viewModel.currentStoryUser

        // Copy the latest models, including updated avatar URLs and like state,
        // but keep the locally tracked seen flag.
        let seenIDs = Set(viewModel.stories.filter(\.isSeen).map(\.id))
        var updated = stories
        for index in updated.indices where seenIDs.contains(updated[index].id) {
            updated[index].isSeen = true
        }
        viewModel.stories = updated

        // Keep the currently visible person's story selected.
        if stories.contains(where: { $0.id == currentUserID }) {
            viewModel.currentStoryUser = currentUserID
        } else if let firstUser = stories.first {
            viewModel.currentStoryUser = firstUser.id
        }
    }
    private func stopVideo() {
        NotificationCenter.default.post(name: .stopVideo, object: nil)
        NotificationCenter.default.removeObserver(self)
    }
}
