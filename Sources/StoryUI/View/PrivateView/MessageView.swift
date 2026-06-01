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
            likeButtonTapped.toggle()
            userClosure?(story, text, nil, likeButtonTapped)
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
            .onChange(of: story, perform: { newValue in
                likeButtonTapped = newValue.isLiked
            })
            .font(.system(size: 17))
            .foregroundColor(.white)
            .frame(height: inputHeight)
            .padding(.horizontal, 16)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
            )
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
        MessageView(story: Story(mediaURL: "", date: Date(), config: StoryConfiguration(mediaType: .image)), showEmoji: .constant(true), userClosure: nil)
    }
}

