//
//  UserView.swift
//  StoryUI (iOS)
//
//  Created by Tolga İskender on 29.04.2022.
//

import SwiftUI

struct UserView: View {
    
    var image: String
    var name: String
    var date: String
    var isMyStory: Bool = false
    var onDeleteTapped: (() -> Void)? = nil
    
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: Constant.UserView.hStackSpace) {
            CacheAsyncImage(urlString: image)
            VStack(alignment: .leading) {
                Text(name)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(date)
                    .font(.system(size: Constant.UserView.textSize, weight: .thin))
                    .foregroundColor(.white)
            }
            
            Spacer()

            // Trash — only for my own stories
            if isMyStory {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .onTapGesture {
                        onDeleteTapped?()
                    }
            }

            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(.leading, 16)   // ← space between trash and xmark
                .onTapGesture {
                    NotificationCenter.default.post(name: .replaceCurrentItem, object: nil)
                    isPresented = false
                }
        }
        .padding(.horizontal)
    }
}
