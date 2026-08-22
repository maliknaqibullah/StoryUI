//
//  SwiftUIView.swift
//
//
//  Created by Naqibullah Malikzada on 1.05.2022.
//

import SwiftUI
import AVKit
import UIKit

struct StoryDetailView: View {
    // MARK: Public Properties
    @ObservedObject var viewModel: StoryViewModel

    @State var model: StoryUIModel
    @Binding var isPresented: Bool
    
    @State var timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()
    @State var timerProgress: CGFloat = 0
    @State var currentStoryProgress: CGFloat = 0
    @Binding var isPaused: Bool

    let userClosure: UserCompletionHandler?
    let onUserChanged: ((String) -> Void)?
    let onAvatarTapped: ((String) -> Void)?
    let onDeleteTapped: ((String) -> Void)?
    let onStoryDisplayed: ((String, String) -> Void)?
    let myUserID: String?
    
    
    // MARK: Private Properties
    /*
     Must be owned by this view. As an @ObservedObject it was rebuilt on every
     re-render, so `isKeyboardOpen` silently fell back to false while the user
     was still typing: the progress timer resumed, the story advanced and the
     composer disappeared out from under the visible keyboard.
    */
    @StateObject private var keyboardManager = KeyboardManager()
    @State private var state: MediaState = .notStarted
    @State private var player = AVPlayer()
    @State private var animate = false
    @State private var selectedEmoji = ""
    @State private var startAnimate = false
    @State private var isTimerRunning: Bool = false
    @State private var isAnimationStarted: Bool = false
    @State private var isTapDisabled: Bool = false
    @State private var showEmoji: Bool = true
    /// Stories already reported as displayed, so each one reports exactly once.
    @State private var displayedStoryIDs: Set<String> = []
    /// The reply composer holds the keyboard focus.
    @State private var isComposerActive: Bool = false
    /// A finger is on the story and this view is the one that paused it.
    @State private var isPausedByTouch: Bool = false
    /// The pause state that was in effect before the finger went down, so a
    /// release restores it instead of blindly resuming a story that some other
    /// feature (viewers sheet, delete dialog) wants stopped.
    @State private var wasPausedBeforeTouch: Bool = false

    private var isMyStory: Bool {
          model.id == myUserID
      }

    /*
     One state for "this story must not move on". Everything that advances the
     story (progress timer, video playback) checks this single value, so the
     composer, the keyboard and an externally requested pause can never end up
     disagreeing about whether the story is running.
    */
    private var isStoryHalted: Bool {
        isPaused || isComposerActive || keyboardManager.isKeyboardOpen
    }
    private var messageViewPosition: CGFloat {
        return -keyboardManager.currentHeight
    }
    
    private var emojiViewPosition: CGFloat {
        return (messageViewPosition * 1.5)
    }
    func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    var body: some View {
        GeometryReader { proxy in
            let index = getCurrentIndex()
            let story = model.stories[index]
            ZStack {
                Color.black
                       .ignoresSafeArea()
                if model.stories.count > index {
                    getStoryView(with: index, story: story)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()

                    storyTouchLayer()

                    /*
                     Subtle separation between the story and the typing state.
                     Sits above the story and its tap layer, below the composer.
                    */
                    if isComposerActive {
                        Color.black
                            .opacity(0.22)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .onTapGesture {
                                closeComposer()
                            }
                    }

                    VStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.5),
                                Color.black.opacity(0.9)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 280)
                        .allowsHitTesting(false)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    VStack {
                        Spacer()

                        HStack(alignment: .center, spacing: 8) {
                            if let title = story.title, !title.isEmpty {
                                Text(title)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            if isMyStory {
                                Button(action: {
                                    NotificationCenter.default.post(
                                        name: .storyViewersTapped,
                                        object: story.id
                                    )
                                }) {
                                    if #available(iOS 15.0, *) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "eye.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("\(story.viewCount)")
                                                .font(.system(size: 12, weight: .bold))
                                                .monospacedDigit()
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                        )
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        if !isMyStory {
                            messageView(with: index)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .glassBackground()
                        }
            
                    }

                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay(
                getUserInfoAndProgressBar(with: index),
                alignment: .top
            )
  
            
        }
        .animation(.easeInOut(duration: 0.2), value: isComposerActive)
        .onChange(of: keyboardManager.isKeyboardOpen) { isOpen in
            if isOpen {
                /*
                 A visible keyboard on a screen without a composer (own story,
                 page changed underneath) is exactly the broken state: get rid
                 of the keyboard instead of leaving it floating there.
                 */
                guard !isMyStory else {
                    dismissKeyboard()
                    return
                }

                //keyboard and composer are one state, never one without the other
                isComposerActive = true

                /*
                 Pause video directly without changing the shared
                 isPaused state.
                 */
                if model.stories[getCurrentIndex()]
                    .config.mediaType == .video {
                    player.pause()
                }
            } else {
                isComposerActive = false

                /*
                 Resume only when another feature has not requested
                 that the story remain paused.
                 */
                if !isPaused {
                    playVideo()
                }
            }
        }
        .onChange(of: isComposerActive) { active in
            /*
             The whole screen has to know: paging, incoming story updates and
             playback all stand still while someone is writing.
            */
            viewModel.isComposerActive = active

            //the composer owns the story while it is active
            if active,
               model.stories[getCurrentIndex()].config.mediaType == .video {
                player.pause()
            }
        }
        .onDisappear {
            /*
             A paging TabView also sends onDisappear for pages it merely
             recycles. Only the page that is no longer the current story may
             tear the composer down — otherwise the keyboard closed under a user
             who was still typing.
            */
            guard viewModel.currentStoryUser != model.id else { return }
            closeComposer()
        }
        .onChange(of: viewModel.currentStoryUser) { newValue in
            closeComposer()

            NotificationCenter.default.post(
                name: .stopVideo,
                object: nil
            )

            currentStoryProgress = 0
            timerProgress = 0
            resetProgress()

            DispatchQueue.main.async {
                if !isStoryHalted {
                    playVideo()
                }
            }

            onUserChanged?(newValue)
        }
        .onReceive(timer) { _ in
            startProgress()
        }
        .onChange(of: isAnimationStarted ? isAnimationStarted : false) { state in
            configureProgress(with: state)
            isTimerRunning = state
        }
        .onChange(of: isPaused) { paused in
            let isVideo =
                model.stories[getCurrentIndex()]
                    .config.mediaType == .video

            guard isVideo else {
                return
            }

            if isStoryHalted {
                player.pause()
            } else {
                playVideo()
            }
        }
        .onChange(of: viewModel.stories) { updated in
            syncMetadataFromViewModel(updated)
        }
        .onReceive(NotificationCenter.default.publisher(for: .storyDeleteTapped)) { _ in
            guard isMyStory else { return }
            let currentStoryID = model.stories[safe: getCurrentIndex()]?.id ?? ""
            onDeleteTapped?(currentStoryID)
        }
    }
}

// MARK: Private Configuration
private extension StoryDetailView {

    /*
     `model` is local state so playback details (isReady, measured video
     duration) survive re-renders. Host-owned metadata such as the like state,
     view count and avatar must still follow the latest data, so copy only
     those fields back in.
    */
    func syncMetadataFromViewModel(_ updated: [StoryUIModel]) {
        guard let latest = updated.first(where: { $0.id == model.id }) else { return }

        model.user = latest.user

        for index in model.stories.indices {
            guard let source = latest.stories.first(where: {
                $0.id == model.stories[index].id
            }) else { continue }

            model.stories[index].isLiked   = source.isLiked
            model.stories[index].viewCount = source.viewCount
            model.stories[index].title     = source.title
        }
    }


    @ViewBuilder
    func getStoryView(with index: Int, story: Story) -> some View {
        switch story.config.mediaType {
        case .image:
            ImageView(imageURL: story.mediaURL) {
                start(index: index)
            }
            .onAppear {
                resetAVPlayer()
            }
        case .video:
            VideoView(
                videoURL: story.mediaURL,
                state: $state,
                player: player
            ) { media, duration in
                model.stories[index].duration = duration
                start(index: index)
                state = media
            }
            .onChange(of: state) { _ in
                playVideo()
            }
        }
    }
    

    
    @ViewBuilder
    func getUserInfoAndProgressBar(with index: Int) -> some View {
        ZStack(alignment: .top) {
            // ← ADD THIS: dark gradient behind top controls
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.5),
                    Color.black.opacity(0.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            VStack {
                HStack(spacing: Constant.progressBarSpacing) {
                    ForEach(model.stories.indices) { i in
                        ProgressBarView(
                            progress: i == getCurrentIndex() ? currentStoryProgress : (i < getCurrentIndex() ? 1.0 : 0.0),
                            isActive: i == getCurrentIndex(),
                            isCompleted: i < getCurrentIndex()
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                UserView(
                    image: model.user.image,
                    name: model.user.name,
                    date: model.stories[safe: index]?.date ?? Date(),
                    isMyStory: isMyStory,
                    isPresented: $isPresented,
                    onAvatarTapped: {
                        guard !isMyStory else {
                            return
                        }

                        /*
                         Stop story progress immediately while the viewer is being
                         dismissed and the app changes tabs.
                         */
                        pauseStory()

                        /*
                         StoryUIModel.id is the author's JID in your mapper.
                         Do not use model.user.id here.
                         */
                        onAvatarTapped?(model.id)
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    func messageView(with index: Int) -> some View {
        let story = getStory(with: index)
        
        MessageView(
            story: story,
            showEmoji: $showEmoji,
            isComposerActive: $isComposerActive,
            draftStore: viewModel.draftStore,
            userClosure: userClosure
        )
        .padding()
        .animation(messageViewPosition == 0 ? .none : .easeOut)
        .offset(y: messageViewPosition)
    }
    
    /*
     Every touch on the story goes through one UIKit layer.

     SwiftUI's `onLongPressGesture(pressing:)` was the cause of the pause
     breaking: it is a *press* gesture, so it cancels as soon as the finger
     travels a few points and reports `pressing = false` while the finger is
     still on the screen — the story resumed under the user's thumb. The touch
     layer below ties the pause to the touch session instead, and it also owns
     the zone taps so there is no second gesture that could cancel the first.
    */
    @ViewBuilder
    func storyTouchLayer() -> some View {
        StoryTouchSurface(
            isEnabled: !isComposerActive && !keyboardManager.isKeyboardOpen,
            locksPaging: isComposerActive || keyboardManager.isKeyboardOpen,
            onHoldBegan: { beginTouchPause() },
            onSessionEnded: { endTouchSession() },
            onTap: { zone in
                switch zone {
                case .leading:
                    tapPreviousStory()
                case .trailing:
                    tapNextStory()
                }
            }
        )
    }

    /// The finger has been down long enough: the story stops and stays stopped
    /// for as long as the touch lasts.
    func beginTouchPause() {
        guard !isPausedByTouch else { return }

        wasPausedBeforeTouch = isPaused
        isPausedByTouch = true
        pauseStory()
    }

    /// The touch ended (lift or system cancel) — the only thing that may undo
    /// a touch pause.
    func endTouchSession() {
        guard isPausedByTouch else { return }

        isPausedByTouch = false

        // A composer opened during the touch keeps the story stopped.
        guard !isComposerActive, !keyboardManager.isKeyboardOpen else { return }

        if wasPausedBeforeTouch {
            pauseStory()
        } else {
            resumeStory()
        }
    }

    /// Tears the composer down as one unit: focus, keyboard and overlay go away
    /// together, and only afterwards may the story run again.
    func closeComposer() {
        if isComposerActive {
            isComposerActive = false
        }
        if viewModel.isComposerActive {
            viewModel.isComposerActive = false
        }
        if keyboardManager.isKeyboardOpen {
            dismissKeyboard()
        }
    }
    
    func resetProgress() {
        timerProgress = 0
    }
    
    func getPreviousStory() {
        if let first = viewModel.stories.first, first.id != model.id {
            let bundleIndex = viewModel.stories.firstIndex { currentBundle in
                return model.id == currentBundle.id
            } ?? 0
            
            // Reset progress before moving to previous user
            currentStoryProgress = 0
            timerProgress = 0
            
            withAnimation {
                viewModel.currentStoryUser = viewModel.stories[bundleIndex - 1].id
            }
        } else {
            let index = getCurrentIndex()
            let story = getStory(with: index)
            
            if index > 0 {
                // Moving to previous story in same user
                currentStoryProgress = 0
                timerProgress = CGFloat(index - 1)
            } else if story.config.mediaType == .video {
                // Already at first story, restart video
                NotificationCenter.default.post(name: .stopAndRestartVideo, object: nil)
                currentStoryProgress = 0
                resetProgress()
            }
        }
    }
    
    func getNextStory() {
        let index = getCurrentIndex()
        let story = getStory(with: index)
        
        if let last = model.stories.last, last.id == story.id {
            if let lastBundle = viewModel.stories.last, lastBundle.id == model.id {
                withAnimation {
                    dissmis()
                }
            } else {
                let bundleIndex = viewModel.stories.firstIndex { currentBundle in
                    return model.id == currentBundle.id
                } ?? 0
                
                // Reset progress before moving to next user
                currentStoryProgress = 0
                timerProgress = 0
                
                withAnimation {
                    viewModel.currentStoryUser = viewModel.stories[bundleIndex + 1].id
                }
            }
        } else {
            // Moving to next story in same user - reset progress
            currentStoryProgress = 0
            timerProgress = CGFloat(index + 1)
        }
    }
    func pauseStory() {
        isPaused = true
        if model.stories[getCurrentIndex()].config.mediaType == .video {
            player.pause()
        }
    }

    func resumeStory() {
        isPaused = false
        if model.stories[getCurrentIndex()].config.mediaType == .video {
            player.play()
        }
    }
    
    func startProgress() {
        guard !isTimerRunning,
              !isStoryHalted
        else {
            return
        }
        let index = getCurrentIndex()
        let story = getStory(with: index)
        
        if viewModel.currentStoryUser == model.id {
            if !model.isSeen {
                model.isSeen = true
            }
            if timerProgress < CGFloat(model.stories.count) {
                if story.isReady {
                    /*
                     The story is on screen, its media is ready and playback is
                     running: this is the moment it counts as displayed.
                    */
                    reportDisplayedIfNeeded(story)

                    let increment = 0.01 / story.duration
                    currentStoryProgress += increment
                    timerProgress = CGFloat(index) + currentStoryProgress
                    
                    if currentStoryProgress >= 1.0 {
                        currentStoryProgress = 0
                        if index + 1 < model.stories.count {
                            timerProgress = CGFloat(index + 1)
                        }
                    }
                }
            } else {
                updateStory()
            }
        }
    }
    func updateStory(direction: StoryDirectionEnum = .next) {
        if direction == .previous {
            getPreviousStory()
        } else {
            getNextStory()
        }
    }
    
    func tapNextStory() {
        guard !isComposerActive, !keyboardManager.isKeyboardOpen else {
            closeComposer()
            return
        }

        configureTapScreen()
        guard !isTapDisabled else {
            return
        }
        
        if (timerProgress + 1) > CGFloat(model.stories.count) {
            // Next user
            updateStory()
        } else {
            // Next story - reset progress for new story
            currentStoryProgress = 0
            timerProgress = CGFloat(Int(timerProgress + 1))
        }
    }

    func tapPreviousStory() {
        guard !isComposerActive, !keyboardManager.isKeyboardOpen else {
            closeComposer()
            return
        }

        configureTapScreen()
        guard !isTapDisabled else {
            return
        }
        
        if (timerProgress - 1) < 0 {
            // Previous user
            updateStory(direction: .previous)
        } else {
            // Previous story - reset progress for new story
            currentStoryProgress = 0
            timerProgress = CGFloat(Int(timerProgress - 1))
        }
    }
    func reportDisplayedIfNeeded(_ story: Story) {
        guard !displayedStoryIDs.contains(story.id) else { return }
        displayedStoryIDs.insert(story.id)
        onStoryDisplayed?(model.id, story.id)
    }

    func start(index: Int) {
        if !model.stories[index].isReady {
            model.stories[index].isReady = true
        }
    }
    
//    func getProgressBarFrame(duration: Double) {
//        let calculatedDuration = viewModel.getVideoProgressBarFrame(duration: duration)
//        timerProgress += (0.01 / calculatedDuration)
//    }
    
    func dissmis() {
        isPresented = false
        NotificationCenter.default.post(name: .replaceCurrentItem, object: nil)
    }
    
    func getCurrentIndex() -> Int {
        return min(Int(timerProgress), model.stories.count - 1)
    }
    
    func getStory(with index: Int) -> Story {
        return model.stories[index]
    }
    
    func resetAVPlayer() {
        Task {
            player.pause()
        }
        player = AVPlayer()
    }
    
    func pauseVideo() {
        player.pause()
    }
    
    func playVideo() {
        //never start playback behind an active composer
        guard !isStoryHalted else { return }

        let index = getCurrentIndex()
        let currentUser = viewModel.currentStoryUser == model.id
        let video = model.stories[index].config.mediaType == .video
        let isReady = state == .ready || state == .started
        
        if isReady, currentUser, video {
            player.automaticallyWaitsToMinimizeStalling = false
            Task {
                player.play()
            }
        }
    }
    
    func configureTapScreen() {
        switch (isComposerActive || keyboardManager.isKeyboardOpen, isAnimationStarted) {
        case (true, _):
            isTapDisabled = true
        case (false, true):
            isTapDisabled = true
        default:
            isTapDisabled = false
        }
    }
    
    func configureProgress(with state: Bool) {
        let index = getCurrentIndex()
        let story = model.stories[index]
        let mediaType = story.config.mediaType
        if state, mediaType == .video {
            pauseVideo()
        } else if !state, mediaType == .video {
            guard viewModel.currentStoryUser == model.id else { return }
            playVideo()
        }
    }
}


private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension View {
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(iOS 15.0, *) {
            self.background(.ultraThinMaterial.opacity(0.7))
        } else {
            self.background(Color.black.opacity(0.3))
        }
    }
}
