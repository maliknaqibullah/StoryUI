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
    /// Story data that arrived while the composer was open, applied as soon as
    /// the user is done writing.
    @State private var pendingStories: [StoryUIModel]?
    @Binding private var isPresented: Bool
    @Binding private var isPaused: Bool

    private var stories: [StoryUIModel]
    private var selectedIndex: Int
    let userClosure: UserCompletionHandler?
    let onUserChanged: ((String) -> Void)?
    let onAvatarTapped: ((String) -> Void)?
    let onDeleteTapped: ((String) -> Void)?
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
        self.onStoryDisplayed = onStoryDisplayed
        self.myUserID = myUserID
    }
    public var body: some View {
        if isPresented {
            ZStack {
                Color.black.ignoresSafeArea()
                TabView(selection: composerSafeSelection) {
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
            .onChange(of: stories) { updated in
                /*
                 Story data keeps arriving while the viewer is open (view
                 counts, reactions, avatars). Handing those updates to the
                 TabView rebuilds its pages, which is exactly what used to tear
                 down the composer seconds after the last keystroke. While
                 someone is writing, the update waits.
                */
                guard !viewModel.isComposerActive else {
                    pendingStories = updated
                    return
                }

                updateStoriesFromParent()
            }
            .onChange(of: viewModel.isComposerActive) { isActive in
                guard !isActive, pendingStories != nil else { return }
                pendingStories = nil
                updateStoriesFromParent()
            }
            .onDisappear {
                // The viewer is gone: nothing may stay locked behind a
                // composer flag that has no composer left.
                viewModel.isComposerActive = false
                pendingStories = nil
                stopVideo()
            }
        }
    }

    /// The visible story may not change while the reply composer is open, so
    /// paging writes are dropped instead of being applied and undone.
    private var composerSafeSelection: Binding<String> {
        Binding(
            get: { viewModel.currentStoryUser },
            set: { newValue in
                guard !viewModel.isComposerActive else { return }
                viewModel.currentStoryUser = newValue
            }
        )
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
