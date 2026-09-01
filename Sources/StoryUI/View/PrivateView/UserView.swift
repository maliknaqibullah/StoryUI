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
    /// The host wants the "..." menu button of this header row.
    var showsMenuButton: Bool = false
    /// The standalone trash button of an own story. Hosts that offer deletion
    /// inside their own "..." menu switch it off to keep one action surface.
    var showsDeleteButton: Bool = true
    /// The standalone close button. Hosts relying on the pull down gesture
    /// alone switch it off.
    var showsCloseButton: Bool = true
    let onAvatarTapped: (() -> Void)?
    @Binding var isPresented: Bool
    
    init(
        image: String,
        name: String,
        date: Date,
        isMyStory: Bool,
        showsMenuButton: Bool = false,
        showsDeleteButton: Bool = true,
        showsCloseButton: Bool = true,
        isPresented: Binding<Bool>,
        onAvatarTapped: (() -> Void)? = nil
    ) {
        self.image = image
        self.name = name
        self.date = date
        self.isMyStory = isMyStory
        self.showsMenuButton = showsMenuButton
        self.showsDeleteButton = showsDeleteButton
        self.showsCloseButton = showsCloseButton
        self._isPresented = isPresented
        self.onAvatarTapped = onAvatarTapped
    }
    
    var body: some View {
        HStack(spacing: Constant.UserView.hStackSpace) {
            if let onAvatarTapped {
                Button(action: onAvatarTapped) {
                    CacheAsyncImage(urlString: image)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(
                        format: NSLocalizedString(
                            "Open chat with %@",
                            comment: "Story avatar accessibility label"
                        ),
                        name
                    )
                )
            } else {
                CacheAsyncImage(urlString: image)
            }
            VStack(alignment: .leading) {
                Text(name)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                RelativeTimeText(date: date)
                    .font(.system(size: Constant.UserView.textSize, weight: .thin))
                    .foregroundColor(.white)
            }
            
            Spacer()

            if showsMenuButton {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .rotationEffect(.degrees(90))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NotificationCenter.default.post(name: .storyMenuTapped, object: nil)
                    }
            }

            if isMyStory && showsDeleteButton {
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

            if showsCloseButton {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NotificationCenter.default.post(name: .replaceCurrentItem, object: nil)
                        isPresented = false
                    }
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
