//
//  SwiftUIView.swift
//
//
//  Created by Naqibullah Malikzada on 3.06.2023.
//

import SwiftUI

struct MessageView: View {

    // MARK: Public Properties
    var story: Story

    @Binding var showEmoji: Bool
    /// True exactly while this composer holds the keyboard focus. The story
    /// stays paused (and the dimming overlay visible) for that whole time.
    @Binding var isComposerActive: Bool
    let userClosure: UserCompletionHandler?

    // MARK: Private Properties
    @State private var text: String = ""
    @State private var likeButtonTapped: Bool = false
    @State private var clearText: Bool = false

    @FocusState private var isMessageFocused: Bool

    private var hasMessageText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let inputHeight: CGFloat = 44
    /// Quick reactions shown inside the reply field while it is idle (WhatsApp
    /// style): the first three emojis of the story's first emoji row.
    private var quickEmojis: [String] {
        if case .message(_, let emojis, _) = story.config.storyType,
           let row = emojis?.first {
            return Array(row.prefix(3))
        }
        return []
    }
    private var showsQuickEmojis: Bool {
        !hasMessageText && !isMessageFocused && !quickEmojis.isEmpty
    }
    private let actionButtonSize: CGFloat = 48
    private let actionIconSize: CGFloat = 38


    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                switch story.config.storyType {
                case .plain(let config):
                    HStack {
                        Spacer()
                        buttonViewBuilder(config)
                    }
                case .message(let config, _, let placeholder):
                    messageViewBuilder(config, placeholder)
                }
            }
        }
        // The like button must always reflect the persisted state of the
        // story that is currently on screen, both on first appearance and
        // whenever the story (or its like state) is refreshed from the host.
        .onAppear { likeButtonTapped = story.isLiked }
        .onChange(of: story.id) { _ in likeButtonTapped = story.isLiked }
        .onChange(of: story.isLiked) { likeButtonTapped = $0 }
        //focus is the single source of truth for "the composer is active"
        .onChange(of: isMessageFocused) { isComposerActive = $0 }
        //the host can close the composer (overlay tap, page change): follow it
        .onChange(of: isComposerActive) { active in
            if !active, isMessageFocused {
                isMessageFocused = false
            }
        }
        .onDisappear { isComposerActive = false }
    }
}

private extension MessageView {
    var onCommitAction: () -> Void {
        return {
            let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !message.isEmpty else { return }

            userClosure?(story, message, nil, false)

            text = ""
            showEmoji = true
            isMessageFocused = false   // dismiss keyboard
        }
    }


    var likeButton: some View  {
        Button {
            let newValue = !likeButtonTapped
            likeButtonTapped = newValue
            // Pass no message here: this tap is a like/unlike only, never a
            // comment. The host decides whether the state actually changed.
            userClosure?(story, nil, nil, newValue)
        } label: {
            Image(systemName: likeButtonTapped ? Constant.MessageView.likeImageTapped : Constant.MessageView.likeImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(likeButtonTapped ? .red : .white)
                .frame(width: actionButtonSize, height: actionButtonSize)
                .contentShape(Circle())
        }
    }

    var sendButton: some View {
        Button {
            onCommitAction()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: actionIconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: actionButtonSize, height: actionButtonSize)
                .contentShape(Circle())
        }
    }

    var shareButton: some View  {
        Button {
        } label: {
            Image(systemName: Constant.MessageView.shareImage)
                .font(.title2)
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    func buttonViewBuilder(_ config: StoryInteractionConfig?) -> some View {
        if let config {
            HStack(spacing: 16) {
                if config.showLikeButton {
                    likeButton
                }
            }
            .frame(width: actionButtonSize, height: actionButtonSize)
        } else {
            EmptyView()
        }
    }


    func messageViewBuilder(_ config: StoryInteractionConfig?, _ placeholder: String) -> some View {
        HStack(spacing: 12) {
            TextField("",
                      text: $text,
                      onCommit: onCommitAction)

            .placeholder(when: text.isEmpty, view: {
                Text(placeholder).foregroundColor(.white.opacity(0.85))
            })
            .onChange(of: text, perform: { newValue in
                showEmoji = newValue.isEmpty
            })
            .onChange(of: clearText, perform: { newValue in
                text = ""
                showEmoji = true
            })
            .font(.system(size: 17))
            .foregroundColor(.white)
            .frame(height: inputHeight)
            .padding(.leading, 16)
            .padding(.trailing, showsQuickEmojis ? 16 + CGFloat(quickEmojis.count) * 40 : 16)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
            )
            .overlay(alignment: .trailing) {
                if showsQuickEmojis {
                    HStack(spacing: 8) {
                        ForEach(quickEmojis, id: \.self) { emoji in
                            Button {
                                //a quick reaction is sent as an emoji reply, like the grid
                                userClosure?(story, nil, emoji, false)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 26))
                                    .frame(width: 32, height: inputHeight)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                    .padding(.trailing, 10)
                }
            }
            .focused($isMessageFocused)
            if hasMessageText {
                sendButton
            } else {
                buttonViewBuilder(config)
            }
        }
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView(story: Story(mediaURL: "", date: Date(), config: StoryConfiguration(mediaType: .image)), showEmoji: .constant(true), isComposerActive: .constant(false), userClosure: nil)
    }
}
