import SwiftUI

/// Bridges the SpriteKit match into the SwiftUI flow. A new `GameViewController` is built for each
/// match, so nothing leaks between fixtures.
struct MatchHostView: UIViewControllerRepresentable {
    let config: MatchConfig
    let onFinish: (MatchResult) -> Void

    func makeUIViewController(context: Context) -> GameViewController {
        GameViewController(config: config, onFinish: onFinish)
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}
