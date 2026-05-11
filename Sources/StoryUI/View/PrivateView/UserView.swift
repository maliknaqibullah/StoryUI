//
//  UserView.swift
//  StoryUI (iOS)
//
//  Created by Naqibullah Malikzada on 29.04.2022.
//

import SwiftUI

struct UserView: View {
    
    var image: String
    var name: String
    var date: Date
    var isMyStory: Bool = false
    
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: Constant.UserView.hStackSpace) {
            CacheAsyncImage(urlString: image)
            VStack(alignment: .leading) {
                Text(name)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                RelativeTimeText(date: date)
                    .font(.system(size: Constant.UserView.textSize, weight: .thin))
                    .foregroundColor(.white)
            }
            
            Spacer()

            if isMyStory {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.45))   // ✅ ADD
                   .clipShape(Circle())
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NotificationCenter.default.post(name: .storyDeleteTapped, object: nil)
                    }
            }

            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.45))   // ✅ ADD
               .clipShape(Circle())
                .contentShape(Rectangle())
                .onTapGesture {
                    NotificationCenter.default.post(name: .replaceCurrentItem, object: nil)
                    isPresented = false
                }
        }
        .padding(.horizontal)
    }
}


public struct RelativeTimeText: View {
    public let date: Date
    @State private var text: String = ""
    
    public init(date: Date) {
        self.date = date
    }
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    
    public var body: some View {
        Text(text)
            .onAppear { text = formatted() }
            .onReceive(timer) { _ in text = formatted() }
    }
    
    private func formatted() -> String {
        let diff = Date().timeIntervalSince(date)
        switch diff {
        case ..<60:     return "Just now"
        case ..<3600:   return "\(Int(diff / 60))m ago"
        case ..<86400:  return "\(Int(diff / 3600))h ago"
        case ..<172800: return "Yesterday"
        default:        return Self.dateFormatter.string(from: date)
        }
    }
}
