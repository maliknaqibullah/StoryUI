//
//  VideoLoader.swift
//  StoryUI (iOS)
//
//  Created by Naqibullah Malikzada on 30.04.2022.
//

import Foundation
import UIKit
import AVKit

final class PlayerView: UIView {

    // MARK: Public Properties
    weak var player: AVPlayer?
    var duration: Double = 0.0
    var state: MediaState = .notStarted
    var mediaState: ((MediaState, Double) -> ())?

    let contentView = UIView()

    // MARK: Private Properties
    private let playerLayer = AVPlayerLayer()
    private var url: URL?

    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private let failureLabel = UILabel()

    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = 12
        self.clipsToBounds = true
        setupPlayer()
        setupFailureLabel()
        addObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    required init?(coder: NSCoder) { nil }

    /// Streams a story video. The item is handed to the player at once: playback starts as soon as
    /// enough of the file has arrived, the whole file is never downloaded first.
    func startVideo(url: URL?) {
        guard let url else { return }
        if self.url == url { return }
        self.url = url
        // stop video if it's playing before the next one is loaded
        stopVideo()
        guard let player else { return }

        failureLabel.isHidden = true
        state = .notStarted
        duration = 0
        addActivityIndicatory()

        let asset = StoryUIMediaProvider.videoAsset?(url) ?? AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        // Enough to bridge short network hiccups, not so much that a long story buffers far ahead.
        item.preferredForwardBufferDuration = 5
        observe(item, of: player)
        player.automaticallyWaitsToMinimizeStalling = true
        player.replaceCurrentItem(with: item)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
        if playerLayer.superlayer == nil {
            contentView.layer.addSublayer(playerLayer)
        }
    }

    /// The view is going away for good: nothing of it may keep playing.
    func tearDown() {
        stopObservingItem()
        url = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerLayer.player = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = contentView.bounds
        CATransaction.commit()
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        // Off screen (the viewer closed or closing) means silent, whatever the SwiftUI state says.
        if newWindow == nil {
            player?.pause()
        }
    }
}

//MARK: - Configure

private extension PlayerView {

    func observe(_ item: AVPlayerItem, of player: AVPlayer) {
        stopObservingItem()

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, self.player?.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    let seconds = item.duration.seconds
                    self.duration = seconds.isFinite && seconds > 0 ? seconds : Constant.storySecond
                    self.state = .ready
                    self.mediaState?(.ready, self.duration)
                case .failed:
                    print("StoryUI: video failed: \(String(describing: item.error))")
                    self.removeActivityIndicatory()
                    self.failureLabel.isHidden = false
                    self.state = .failed
                    self.mediaState?(.failed, Constant.storySecond)
                default:
                    break
                }
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self, self.player === player, player.currentItem === item else { return }
                switch player.timeControlStatus {
                case .playing:
                    // Safety net: a player that is not on screen never plays.
                    guard self.window != nil else {
                        player.pause()
                        return
                    }
                    self.removeActivityIndicatory()
                    self.state = .started
                    self.mediaState?(.started, self.duration)
                case .waitingToPlayAtSpecifiedRate:
                    // Buffering: the story waits for the network, and shows it.
                    self.addActivityIndicatory()
                default:
                    self.removeActivityIndicatory()
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.mediaState?(.finished, self.duration)
        }
    }

    func stopObservingItem() {
        statusObservation = nil
        timeControlObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    func stopAndRestartVideo() {
        player?.seek(to: .zero)
    }

    func stopVideo() {
        // Always, not only while playing: a video still buffering would otherwise start on its own.
        player?.pause()
        if player?.currentItem != nil {
            player?.seek(to: .zero)
        }
        state = .stopped
    }

    func restartVideo() {
        if player?.timeControlStatus == .paused {
            player?.seek(to: .zero)
            player?.play()
            state = .restart
        }
    }

    func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartVideoObserver),
            name: .restartVideo,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopVideoObserver),
            name: .stopVideo,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopAndRestartVideoObserver),
            name: .stopAndRestartVideo,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(replaceCurrentItemObserver),
            name: .replaceCurrentItem,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc
    func stopAndRestartVideoObserver() {
        stopAndRestartVideo()
    }

    @objc
    func restartVideoObserver() {
        restartVideo()
    }

    @objc
    func stopVideoObserver() {
        stopVideo()
    }

    @objc
    func replaceCurrentItemObserver() {
        tearDown()
        self.player = nil
    }

    @objc
    func applicationDidEnterBackground() {
        // The story viewer resumes it when the app is active again.
        player?.pause()
    }
}

// MARK: - Setup Func

private extension PlayerView {
    func addActivityIndicatory() {
        guard !subviews.contains(where: { $0.tag == 999 }) else { return }
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let view = UIView(frame: CGRect(x: 0, y: 0, width: w, height: h))
        // Buffering mid video keeps the last frame visible under the spinner.
        view.backgroundColor = state == .started ? .clear : .black
        view.isUserInteractionEnabled = false
        view.tag = 999
        self.addSubview(view)
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.color = UIColor.lightGray.withAlphaComponent(0.7)
        activityView.frame = CGRect(x: w / 2, y: h / 2, width: .zero, height: .zero)
        view.addSubview(activityView)
        addConst(view: activityView)
        activityView.startAnimating()
    }

    func setupPlayer() {
        self.addSubview(contentView)
        contentView.frame.size.width = self.frame.size.width
        contentView.frame.size.height = self.frame.size.height
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
            contentView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: 0),
            contentView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            contentView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
        ])
        playerLayer.frame = contentView.frame
    }

    func setupFailureLabel() {
        failureLabel.text = NSLocalizedString("This video can't be played", comment: "story video failed to load")
        failureLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        failureLabel.font = .systemFont(ofSize: 15, weight: .medium)
        failureLabel.textAlignment = .center
        failureLabel.numberOfLines = 0
        failureLabel.isHidden = true
        failureLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(failureLabel)
        NSLayoutConstraint.activate([
            failureLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            failureLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            failureLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
        ])
    }

    func removeActivityIndicatory() {
        self.subviews.forEach { (view) in
            if view.tag == 999 {
                view.removeFromSuperview()
            }
        }
    }

    func addConst(view: UIActivityIndicatorView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: view.superview!.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: view.superview!.centerYAnchor)
        ])
    }
}
