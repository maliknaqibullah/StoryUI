//
//  StoryDraftStore.swift
//  StoryUI
//

import Foundation

/// Unsent reply texts, per story.
///
/// A plain reference type on purpose: drafts change on every keystroke and must
/// not publish anything, or typing would re-render the whole story screen. It
/// outlives any single composer instance, so a draft survives a page rebuild,
/// a story refresh and a trip to another story and back.
final class StoryDraftStore {

    private var drafts: [String: String] = [:]

    func draft(for storyID: String) -> String {
        drafts[storyID] ?? ""
    }

    func setDraft(_ text: String, for storyID: String) {
        if text.isEmpty {
            drafts.removeValue(forKey: storyID)
        } else {
            drafts[storyID] = text
        }
    }

    func clearDraft(for storyID: String) {
        drafts.removeValue(forKey: storyID)
    }
}
