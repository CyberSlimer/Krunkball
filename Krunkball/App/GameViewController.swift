import UIKit
import SpriteKit

/// Hosts the SpriteKit match. UIKit rather than pure SwiftUI so the SKView can be first responder
/// and receive hardware-keyboard presses (handy in the Simulator and on an iPad).
final class GameViewController: UIViewController {
    private var matchScene: MatchScene?
    private let config: MatchConfig
    private let onFinish: (MatchResult) -> Void

    init(config: MatchConfig, onFinish: @escaping (MatchResult) -> Void) {
        self.config = config
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SKView()
    }

    override var canBecomeFirstResponder: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.isMultipleTouchEnabled = true
        #if DEBUG
        skView.showsFPS = true
        #endif

        let scene = MatchScene(config: config, size: skView.bounds.size)
        scene.safeInsets = view.safeAreaInsets
        scene.onFinish = { [weak self] result in
            // Let the FULL TIME card sit for a beat before the result screen slides over it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                self?.onFinish(result)
            }
        }
        matchScene = scene
        skView.presentScene(scene)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        matchScene?.safeInsets = view.safeAreaInsets
    }

    // MARK: Hardware keyboard (Simulator / iPad keyboard) — WASD or arrows, G / H / J like the original

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            if let key = press.key, matchScene?.keyDown(key.keyCode) == true { continue }
            unhandled.insert(press)
        }
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key { matchScene?.keyUp(key.keyCode) }
        }
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key { matchScene?.keyUp(key.keyCode) }
        }
        super.pressesCancelled(presses, with: event)
    }
}
