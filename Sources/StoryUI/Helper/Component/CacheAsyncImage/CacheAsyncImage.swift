//
//  CacheAsyncImage.swift
//  StoryUI (iOS)
//
//  Created by Naqibullah Malikzada on 1.05.2022.
//

import SwiftUI

/// The avatar in the story header.
///
/// It used to create its loader as an `@ObservedObject` in `init`: the header is rebuilt on every
/// tick of the 10 ms progress timer, so every tick threw the loader away together with any image it
/// had fetched, and only a synchronous URL cache hit ever showed. An avatar whose cache entry was not
/// written yet (or never stored) stayed a gray circle until the viewer was opened again. Images now
/// come from the host first, then from a memory cache, synchronously, and a fetch is owned by the
/// view (`@StateObject`) so its result survives the re-renders.
struct CacheAsyncImage: View {
    let urlString: String?
    @StateObject private var urlImageModel = UrlImageModel()

    init(urlString: String?) {
        self.urlString = urlString
    }

    var body: some View {
        if let image = UrlImageModel.immediateImage(for: urlString)
            ?? urlImageModel.image(for: urlString) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            Color.gray.opacity(0.8)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .onAppear { urlImageModel.load(urlString) }
                .onChange(of: urlString) { urlImageModel.load($0) }
        }
    }
}


final class UrlImageModel: ObservableObject {
    @Published private var loadedImage: UIImage?
    private var loadedURLString: String?
    private var task: URLSessionDataTask?

    private static let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    /// An image available without waiting: the host's, or one decoded before.
    static func immediateImage(for urlString: String?) -> UIImage? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if let image = StoryUIMediaProvider.image?(urlString) {
            return image
        }
        if let image = memoryCache.object(forKey: urlString as NSString) {
            return image
        }
        // The header asks on every progress tick; a miss is not looked up on disk again right away.
        if let lastMiss = urlCacheMisses[urlString], Date().timeIntervalSince(lastMiss) < 0.5 {
            return nil
        }
        guard let url = URL(string: urlString),
              let cachedResponse = URLCache.shared.cachedResponse(for: .init(url: url)),
              let image = UIImage(data: cachedResponse.data)
        else {
            urlCacheMisses[urlString] = Date()
            return nil
        }
        urlCacheMisses[urlString] = nil
        memoryCache.setObject(image, forKey: urlString as NSString)
        return image
    }

    /// Main thread only, like every caller of `immediateImage`.
    private static var urlCacheMisses: [String: Date] = [:]

    func image(for urlString: String?) -> UIImage? {
        guard let urlString, urlString == loadedURLString else { return nil }
        return loadedImage
    }

    func load(_ urlString: String?) {
        guard let urlString, !urlString.isEmpty, urlString != loadedURLString else { return }
        loadedURLString = urlString
        loadedImage = nil
        task?.cancel()
        task = nil

        if let image = Self.immediateImage(for: urlString) {
            loadedImage = image
            return
        }
        guard let url = URL(string: urlString) else { return }

        let request = URLRequest(url: url)
        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let data, let response, let image = UIImage(data: data) else { return }

            URLCache.shared.storeCachedResponse(
                .init(response: response, data: data),
                for: request
            )
            Self.memoryCache.setObject(image, forKey: urlString as NSString)

            DispatchQueue.main.async {
                guard let self, self.loadedURLString == urlString else { return }
                self.loadedImage = image
            }
        }
        task?.resume()
    }
}
