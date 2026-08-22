//
//  StoryViewModel.swift
//  StoryUI (iOS)
//
//  Created by Naqibullah Malikzada on 28.04.2022.
//

import Foundation

final class StoryViewModel: ObservableObject {
    
    @Published var currentStoryUser: String = ""
    @Published var stories: [StoryUIModel] = []
    /*
     True while a reply composer holds the keyboard focus. Everything that could
     pull the story out from under the user — paging, incoming story updates —
     reads this value.

     Deliberately *not* `@Published`: publishing on focus gain rebuilds the
     TabView pages at the exact moment the text field becomes first responder,
     which drops the focus again and the keyboard never opens. Only the closing
     edge is published, through `composerClosedCount`, because by then the
     keyboard is going away anyway and a rebuild is harmless.
    */
    private(set) var isComposerActive: Bool = false

    /// Bumped every time the composer closes, so views that queued work while
    /// someone was writing know when they may run it.
    @Published private(set) var composerClosedCount: Int = 0

    /// Unsent reply texts. Not published: typing must not re-render the story.
    let draftStore = StoryDraftStore()

    func setComposerActive(_ active: Bool) {
        guard isComposerActive != active else { return }

        isComposerActive = active

        if !active {
            composerClosedCount += 1
        }
    }

    func getVideoProgressBarFrame(duration: Double) -> Double {
        return duration * 0.1 // convert any second to  between 0 - 1 second
    }
    
    func getStoryModel() -> StoryUIModel? {
        if let i = stories.firstIndex(where: { $0.id == currentStoryUser }) {
            return stories[i]
        }
        return nil
    }
    
    func getStories() -> [Story]? {
        return getStoryModel()?.stories
    }
    
    func getStory(with index: Int) -> Story? {
        return getStories()?[index]
    }
}
