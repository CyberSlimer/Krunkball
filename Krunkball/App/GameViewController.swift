import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private var matchScene: MatchScene?

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

        let scene = MatchScene(teams: Roster.demoTeams(), size: skView.bounds.size)
        scene.safeInsets = view.safeAreaInsets
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
