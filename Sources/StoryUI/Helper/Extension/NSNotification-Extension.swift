//
//  File.swift
//  
//
//  Created by Tolga İskender on 1.05.2022.
//

import Foundation

public extension NSNotification.Name {
    static let stopVideo = Notification.Name("stopVideo")
    static let restartVideo = Notification.Name("restartVideo")
    static let replaceCurrentItem = Notification.Name("replaceCurrentItem")
    static let stopAndRestartVideo = Notification.Name("stopAndRestartVideo")
    static let storyDeleteTapped = Notification.Name("storyDeleteTapped")
    static let storyViewersTapped = Notification.Name("storyViewersTapped")

}
