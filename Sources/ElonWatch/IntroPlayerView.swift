import SwiftUI
import AVFoundation
import AppKit

// MARK: - AVPlayerLayer wrapped in NSViewRepresentable
// Avoids the _AVKit_SwiftUI VideoPlayer crash on macOS 26 (Xcode 26).

struct AVPlayerLayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = PlayerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? PlayerNSView {
            view.player = player
        }
    }

    class PlayerNSView: NSView {
        var playerLayer: AVPlayerLayer?

        var player: AVPlayer? {
            didSet { playerLayer?.player = player }
        }

        override func makeBackingLayer() -> CALayer {
            let layer = AVPlayerLayer()
            layer.videoGravity = .resizeAspectFill
            layer.backgroundColor = NSColor.black.cgColor
            self.playerLayer = layer
            playerLayer?.player = player
            return layer
        }

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            playerLayer?.frame = bounds
        }
    }
}

// MARK: - Intro splash view

struct IntroPlayerView: View {
    let onComplete: () -> Void

    @State private var player: AVPlayer?
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                AVPlayerLayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .opacity(opacity)
        .onAppear { startPlayback() }
    }

    private func startPlayback() {
        guard let url = Bundle.main.url(forResource: "intro", withExtension: "mp4") else {
            onComplete()
            return
        }

        let item = AVPlayerItem(url: url)
        let p    = AVPlayer(playerItem: item)
        p.volume = 1.0
        self.player = p

        withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.4)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onComplete()
            }
        }

        p.play()
    }
}
