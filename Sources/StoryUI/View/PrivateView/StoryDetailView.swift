//
//  SwiftUIView.swift
//
//
//  Created by Tolga İskender on 1.05.2022.
//

import SwiftUI
import AVKit

struct StoryDetailView: View {
    // MARK: Public Properties
    @ObservedObject var viewModel: StoryViewModel

    @State var model: StoryUIModel
    @Binding var isPresented: Bool
    
    @State var timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()
    @State var timerProgress: CGFloat = 0
    @State var currentStoryProgress: CGFloat = 0
    @State private var isPaused: Bool = false

    let userClosure: UserCompletionHandler?
    let onUserChanged: ((String) -> Void)?    // ← ADD
    let onDeleteTapped: ((String) -> Void)?
    let myUserID: String?
    
    
    // MARK: Private Properties
    @ObservedObject private var keyboardManager = KeyboardManager()
    @State private var state: MediaState = .notStarted
    @State private var player = AVPlayer()
    @State private var animate = false
    @State private var selectedEmoji = ""
    @State private var startAnimate = false
    @State private var isTimerRunning: Bool = false
    @State private var isAnimationStarted: Bool = false
    @State private var isTapDisabled: Bool = false
    @State private var showEmoji: Bool = true

    private var isMyStory: Bool {
          model.id == myUserID
      }
    private var messageViewPosition: CGFloat {
        return -keyboardManager.currentHeight
    }
    
    private var emojiViewPosition: CGFloat {
        return (messageViewPosition * 1.5)
    }
    
    var body: some View {
        
        GeometryReader { proxy in
            let index = getCurrentIndex()
            let story = model.stories[index]
            ZStack {
                if model.stories.count > index {
                    VStack(spacing: 8) {
                        getStoryView(with: index, story: story)
                            .overlay(
                                tapStory()
                                    .offset(
                                        y: story.config.storyType != .plain()
                                        ? -Constant.MessageView.height : .zero
                                    )
                            )
                        if let title = model.user.title, !title.isEmpty {
                              HStack {
                                  Text(title)
                                      .font(.system(size: 20, weight: .semibold))
                                      .foregroundColor(.white)
                                      .multilineTextAlignment(.leading)
                                      .lineLimit(2)
                                      .padding(.horizontal, 16)
                                      .padding(.vertical, 10)
                              }
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .background(
                                  LinearGradient(
                                      colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                                      startPoint: .top,
                                      endPoint: .bottom
                                  )
                              )
                          }
                        messageView(with: index)
                    }
                }
                getEmojiView(story: story)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay(
                getUserInfoAndProgressBar(with: index)
                ,alignment: .top
            )
            .rotation3DEffect(
                getAngle(proxy: proxy),
                axis: (x: 0, y: 1, z: 0),
                anchor: proxy.frame(in: .global).minX > 0 ? .leading : .trailing,
                perspective: 2.5
            )
        }
        .onChange(of: viewModel.currentStoryUser) { newValue in
            NotificationCenter.default.post(name: .stopVideo, object: nil)
            currentStoryProgress = 0 // Add this line
            timerProgress = 0 // Add this line
            resetProgress()
            playVideo()
            onUserChanged?(newValue)          // ← ADD this one line

        }
        .onReceive(timer) { _ in
            startProgress()
        }
        .onChange(of: isAnimationStarted ? isAnimationStarted : false) { state in
            configureProgress(with: state)
            isTimerRunning = state
        }
        .onReceive(NotificationCenter.default.publisher(for: .storyDeleteTapped)) { _ in
            guard isMyStory else { return }
            let currentStoryID = model.stories[safe: getCurrentIndex()]?.id ?? ""
            onDeleteTapped?(currentStoryID)   // ← pass story ID not model ID
        }
    }
}

// MARK: Private Configuration
private extension StoryDetailView {
    
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
    func getEmojiView(story: Story) -> some View {
        let index = getCurrentIndex()
        switch story.config.storyType {
        case .message(_, let emojis, _):
            if let emojis, showEmoji {
                VStack {
                    Spacer()
                    EmojiView(
                        story: getStory(with: index),
                        emojiArray: emojis,
                        startAnimating: $startAnimate,
                        selectedEmoji: $selectedEmoji,
                        userClosure: userClosure
                    )
                    .animation(messageViewPosition == 0 ? .none : .easeOut)
                    .offset(y: emojiViewPosition)
                    .opacity(messageViewPosition == 0 ? 0 : 1)
                }
                
                if startAnimate {
                    EmojiReactionView(
                        dissmis: $startAnimate,
                        isAnimationStarted: $isAnimationStarted,
                        emoji: selectedEmoji
                    )
                }
                
            }
        case .plain:
            Divider()
        }
    }
    
    @ViewBuilder
    func getUserInfoAndProgressBar(with index: Int) -> some View {
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
                image:     model.user.image,
                name:      model.user.name,
                date:      model.stories[safe: index]?.date ?? "",
                isMyStory: isMyStory,
                isPresented: $isPresented
            )
        }
    }
    @ViewBuilder
    func messageView(with index: Int) -> some View {
        let story = getStory(with: index)
        
        MessageView(
            story: story,
            showEmoji: $showEmoji,
            userClosure: userClosure
        )
        .padding()
        .animation(messageViewPosition == 0 ? .none : .easeOut)
        .offset(y: messageViewPosition)
    }
    
    @ViewBuilder
    func tapStory() -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(.black.opacity(0.01))
                .onTapGesture {
                    tapPreviousStory()
                }
                .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                    if isPressing {
                        pauseStory()
                    } else {
                        resumeStory()
                    }
                }, perform: {})
            
            Rectangle()
                .fill(.black.opacity(0.01))
                .onTapGesture {
                    tapNextStory()
                }
                .onLongPressGesture(minimumDuration: 0.2, pressing: { isPressing in
                    if isPressing {
                        pauseStory()
                    } else {
                        resumeStory()
                    }
                }, perform: {})
        }
    }
    
    func getAngle(proxy: GeometryProxy) -> Angle {
        let rotation: CGFloat = 45
        let progress = proxy.frame(in: .global).minX / proxy.size.width
        let degrees = rotation * progress
        return Angle(degrees: degrees)
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
        guard !isTimerRunning && !isPaused else { return }
        
        let index = getCurrentIndex()
        let story = getStory(with: index)
        
        if viewModel.currentStoryUser == model.id {
            if !model.isSeen {
                model.isSeen = true
            }
            if timerProgress < CGFloat(model.stories.count) {
                if story.isReady {
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
        configureTapScreen()
        guard !isTapDisabled else { return }
        
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
        configureTapScreen()
        guard !isTapDisabled else { return }
        
        if (timerProgress - 1) < 0 {
            // Previous user
            updateStory(direction: .previous)
        } else {
            // Previous story - reset progress for new story
            currentStoryProgress = 0
            timerProgress = CGFloat(Int(timerProgress - 1))
        }
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
        switch (keyboardManager.isKeyboardOpen, isAnimationStarted) {
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
