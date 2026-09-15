import AVFoundation
import UIKit

/// The session a sound is played through, which is what decides whether it is heard at all.
///
/// An application is silent under the ring switch until it says that playing is what it is for, so a
/// player that never asks plays nothing on a phone that is on silent, which is most of them.
enum VarnAudioSession {
    static func playback() {
        let session = AVAudioSession.sharedInstance()

        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }
}

/// A sound with no picture and no player of its own.
///
/// What draws a player is the tree, so this view is never seen. It is told whether it should be playing
/// and where to be, and it reports where it has got to and how long the whole thing is.
final class VarnAudioView: UIView {
    private(set) var player = AVPlayer()
    private var watching: Any?
    private var ended: NSObjectProtocol?
    private var announced = false

    var onProgress: (([String: Any]) -> Void)?
    var onReady: (([String: Any]) -> Void)?
    var onEnd: (() -> Void)?
    var onError: (([String: Any]) -> Void)?

    private var failure: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        watch()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit {
        if let watching {
            player.removeTimeObserver(watching)
        }

        if let ended {
            NotificationCenter.default.removeObserver(ended)
        }
    }

    func setSource(_ value: String?) {
        guard let value, let url = VarnAudioView.url(of: value) else {
            player.replaceCurrentItem(with: nil)
            return
        }

        VarnAudioSession.playback()

        announced = false

        let item = AVPlayerItem(url: url)

        // A sound that cannot be opened at all leaves a play button that does nothing and says nothing.
        failure = item.observe(\.status) { [weak self] observed, _ in
            guard observed.status == .failed else {
                return
            }

            let problem = observed.error?.localizedDescription ?? "the sound could not be opened"
            DispatchQueue.main.async { self?.onError?(["message": problem]) }
        }

        player.replaceCurrentItem(with: item)
    }

    func setPlaying(_ value: Bool) {
        if value {
            player.play()
            return
        }

        player.pause()
    }

    func setLoops(_ value: Bool) {
        loops = value
    }

    func setVolume(_ value: Float) {
        player.volume = value
    }

    func setRate(_ value: Float) {
        rate = value

        if player.rate != 0 {
            player.rate = value
        }
    }

    /// Moves to a moment, which is a reader dragging a scrubber rather than anything the tree describes.
    func seek(to seconds: Double) {
        let whole = player.currentItem?.duration.seconds ?? 0
        let bound = whole.isFinite ? whole : seconds
        let wanted = CMTime(seconds: max(0, min(seconds, bound)), preferredTimescale: 600)

        // The completion is not promised on any particular queue, and what it does reaches the tree.
        player.seek(to: wanted, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.report(at: self.player.currentTime().seconds)
            }
        }
    }

    private var loops = false
    private var rate: Float = 1

    private func watch() {
        let every = CMTime(seconds: 0.25, preferredTimescale: 600)

        watching = player.addPeriodicTimeObserver(forInterval: every, queue: .main) { [weak self] time in
            self?.report(at: time.seconds)
        }

        // The notice names the item that finished, and every item in the process raises the same one, so
        // a screen holding two sounds tells both of them that one of them ended.
        ended = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, note.object as AnyObject? === self.player.currentItem else {
                return
            }

            if self.loops {
                self.player.seek(to: .zero)
                self.player.play()
                return
            }

            self.onEnd?()
        }
    }

    private func report(at position: Double) {
        let whole = player.currentItem?.duration.seconds ?? 0
        let duration = whole.isFinite ? whole : 0

        if !announced, duration > 0 {
            announced = true
            onReady?(["duration": duration])
        }

        onProgress?(["position": position, "duration": duration])
    }

    private static func url(of source: String) -> URL? {
        if source.contains("://") {
            return URL(string: source)
        }

        return URL(fileURLWithPath: source)
    }
}
