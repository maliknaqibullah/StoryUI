//
//  User.swift
//  StoryUI (iOS)
//
//  Created by Naqibullah Malikzada on 1.05.2022.
//

import Foundation

public struct StoryUIUser: Identifiable, Hashable {
    public var id:    String
    public var name:  String
    public var image: String
    public var title: String?    // ✅ ADD

    public init(id: String = UUID().uuidString, name: String, image: String, title: String? = nil) {
        self.id    = id
        self.name  = name
        self.image = image
        self.title = title       // ✅ ADD
    }
}
