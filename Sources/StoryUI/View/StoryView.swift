//
//  StoryView.swift
//  StoryUI (iOS)
//
//  Created by Tolga İskender on 28.04.2022.
//

import SwiftUI
import AVFoundation

public struct StoryView: View {
    
    @StateObject private var viewModel = StoryViewModel()
    @Binding private var isPresented: Bool
    @State private var isPaused: Bool = false  // ← ADD
    
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
        userClosure: UserCompletionHandler? = nil,
        onUserChanged: ((String) -> Void)? = nil,
        onDeleteTapped: ((String) -> Void)? = nil,
        myUserID: String? = nil
    ) {
        self.stories = stories
        self.selectedIndex = selectedIndex
        self._isPresented = isPresented
        self.userClosure = userClosure
        self.onUserChanged = onUserChanged
        self.onDeleteTapped = onDeleteTapped
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
                            isPaused: $isPaused,         // ← ADD
                            userClosure: userClosure,
                            onUserChanged: onUserChanged,
                            onDeleteTapped: onDeleteTapped,
                            myUserID: myUserID
                        )
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .tabViewStyle(.page(indexDisplayMode: .never))
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
