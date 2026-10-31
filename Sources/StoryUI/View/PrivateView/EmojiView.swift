//
//  SwiftUIView.swift
//
//
//  Created by Naqibullah Malikzada on 4.06.2023.
//

import SwiftUI

struct EmojiView: View {
    
    var story: Story
    var emojiArray: [[String]]?
    
    @Binding var startAnimating: Bool
    @Binding var selectedEmoji: String
    
    let userClosure: UserCompletionHandler?
    
    private let emojiSize: CGFloat = 44
    private let spacing: CGFloat = 36
    
    var body: some View {
        if let emojiArray = emojiArray {
            VStack(spacing: spacing) {
                Text("Tap to send")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.9))
                ForEach(0..<emojiArray.count, id: \.self) { index in
                    HStack(spacing: spacing) {
                        ForEach(0..<emojiArray[index].count, id: \.self) { icon in
                            Button(action: {
                                let emoji = emojiArray[index][icon]
                                startAnimate()
                                select(emoji: emoji)
                                dismissKeyboard()
                                userClosure?(story, nil, emoji, false)
                            }) {
                                Text(emojiArray[index][icon])
                            }
                            .font(.system(size: emojiSize))
                        }
                    }
                }
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.endEditing(true)
    }
    
    private func select(emoji: String) {
        selectedEmoji = emoji
    }
    
    private func startAnimate() {
       startAnimating = true
    }
}

struct EmojiView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiView(story: .init(mediaURL: "", date: Date(), config: StoryConfiguration(mediaType: .image)),
                  emojiArray: [["😂", "😮", "😍"]],
                  startAnimating: .constant(false),
                  selectedEmoji: .constant("🤪"),
                  userClosure: nil)
    }
}
