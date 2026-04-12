//
//  StoryUIUser.swift
//  StoryUI
//
//  Created by Tolga İskender on 28.03.2022.
//

import Foundation

public struct Story: Identifiable, Hashable {
    public var id: String
    public var mediaURL: String
    public var date: String
    public var isReady: Bool = false
    public var isLiked: Bool = false
    public var duration: Double = Constant.storySecond
    public var config: StoryConfiguration
    public var title: String?
    public var viewCount: Int = 0
    public init(id: String = UUID().uuidString,
                mediaURL: String,
                date: String,
                isLiked: Bool = false,
                duration: Double = 5,
                config: StoryConfiguration,
                viewCount: Int = 0,
                title: String? = nil) {
        
        self.id = id
        self.mediaURL = mediaURL
        self.date = date
        self.duration = duration
        self.config = config
        self.isLiked = isLiked
        Constant.storySecond = duration
        self.title = title
        self.viewCount = viewCount
    }
}

