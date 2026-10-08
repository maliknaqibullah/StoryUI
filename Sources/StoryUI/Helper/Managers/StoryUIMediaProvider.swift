//
//  StoryUIMediaProvider.swift
//  StoryUI
//

import AVFoundation
import UIKit

/// Hooks a host app sets to hand StoryUI media from its own loaders and caches.
///
/// Both are read on the main thread.
public enum StoryUIMediaProvider {

    /// The asset to play for a video story's URL.
    ///
    /// Without it the URL is played as a plain `AVURLAsset`, which streams only from servers that
    /// answer byte-range requests. A host whose media server does not (or that keeps its own video
    /// cache) returns an asset backed by its own resource loader or local file here.
    public static var videoAsset: ((URL) -> AVURLAsset)?

    /// An image the host already holds for an image URL, such as an avatar under a URL that exists
    /// only inside the app. Checked synchronously, before any cache or network.
    public static var image: ((String) -> UIImage?)?
}
