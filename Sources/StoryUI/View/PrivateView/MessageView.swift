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
    /// Survives this view: a draft is never lost to a rebuild of the page.
    let draftStore: StoryDraftStore
    let userClosure: UserCompletionHandler?

    // MARK: Private Properties
    @State private var text: String = ""
    @State private var likeButtonTapped: Bool = false
    @State private var isInputFocused: Bool = false

    private var hasMessageText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let inputHeight: CGFloat = 44
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
        .onAppear {
            likeButtonTapped = story.isLiked
            restoreDraft(for: story.id)
        }
        .onChange(of: story.id) { newID in
            likeButtonTapped = story.isLiked
            restoreDraft(for: newID)
        }
        .onChange(of: story.isLiked) { likeButtonTapped = $0 }
        //focus is the single source of truth for "the composer is active"
        .onChange(of: isInputFocused) { isComposerActive = $0 }
        //the host can close the composer (overlay tap, page change): follow it
        .onChange(of: isComposerActive) { active in
            if !active, isInputFocused {
                isInputFocused = false
            }
        }
        /*
         Only the story really leaving the screen ends the composer. The typed
         text stays in the draft store, so coming back restores it.
        */
        .onDisappear { isComposerActive = false }
    }
}

private extension MessageView {
    func restoreDraft(for storyID: String) {
        let stored = draftStore.draft(for: storyID)
        if text != stored {
            text = stored
        }
        showEmoji = stored.isEmpty
    }

    var onCommitAction: () -> Void {
        return {
            let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !message.isEmpty else { return }

            userClosure?(story, message, nil, false)

            text = ""
            draftStore.clearDraft(for: story.id)
            showEmoji = true
            isInputFocused = false   // dismiss keyboard
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
            StoryComposerTextField(
                text: $text,
                isFocused: $isInputFocused,
                placeholder: placeholder,
                onSubmit: onCommitAction
            )
            .onChange(of: text) { newValue in
                draftStore.setDraft(newValue, for: story.id)
                showEmoji = newValue.isEmpty
            }
            .frame(height: inputHeight)
            .padding(.horizontal, 16)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
            )
            .contentShape(Capsule())
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
        MessageView(
            story: Story(mediaURL: "", date: Date(), config: StoryConfiguration(mediaType: .image)),
            showEmoji: .constant(true),
            isComposerActive: .constant(false),
            draftStore: StoryDraftStore(),
            userClosure: nil
        )
    }
}
