import SwiftUI
import AVKit
import AVFoundation

// MARK: - Intro splash: plays intro.mp4 fullscreen, then fires onComplete

struct IntroPlayerView: View {
    let onComplete: () -> Void

    @State private var player: AVPlayer?
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .disabled(true)          // no controls
            }
        }
        .opacity(opacity)
        .onAppear { startPlayback() }
    }

    private func startPlayback() {
        guard let url = Bundle.main.url(forResource: "intro", withExtension: "mp4") else {
            // No video found — skip straight to app
            onComplete()
            return
        }

        let item   = AVPlayerItem(url: url)
        let p      = AVPlayer(playerItem: item)
        p.isMuted  = false
        p.volume   = 1.0
        self.player = p

        // Fade in
        withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }

        // Observe end of playback
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
