import SpriteKit

/// Floating virtual stick on the left half of the screen plus two action buttons on the right.
/// Lives as a child of the camera, so its coordinate space is screen points centred on the view.
final class TouchControls: SKNode {
    private(set) var stickVector = CGVector.zero
    private var keyVector = CGVector.zero
    private var pendingPrimary = false
    private var pendingSecondary = false

    private var stickTouch: UITouch?
    private var stickOrigin = CGPoint.zero
    private let stickRadius: CGFloat = 60
    private let stickBase = SKShapeNode(circleOfRadius: 60)
    private let stickKnob = SKShapeNode(circleOfRadius: 26)

    let primaryButton = SKShapeNode(circleOfRadius: 44)
    let secondaryButton = SKShapeNode(circleOfRadius: 44)
    private let primaryLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let secondaryLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    /// Stick input wins while a finger is down; otherwise fall back to the keyboard vector.
    var moveVector: CGVector { stickTouch != nil ? stickVector : keyVector }

    override init() {
        super.init()
        zPosition = 100

        stickBase.fillColor = SKColor.white.withAlphaComponent(0.08)
        stickBase.strokeColor = SKColor.white.withAlphaComponent(0.35)
        stickBase.lineWidth = 2
        stickBase.isHidden = true
        stickKnob.fillColor = SKColor.white.withAlphaComponent(0.35)
        stickKnob.strokeColor = .clear
        stickKnob.isHidden = true

        configure(button: primaryButton, label: primaryLabel, tint: SKColor(red: 0.2, green: 0.6, blue: 1, alpha: 1))
        configure(button: secondaryButton, label: secondaryLabel, tint: SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1))
        setLabels(hasBall: false)

        addChild(stickBase)
        addChild(stickKnob)
        addChild(primaryButton)
        addChild(secondaryButton)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(button: SKShapeNode, label: SKLabelNode, tint: SKColor) {
        button.fillColor = tint.withAlphaComponent(0.28)
        button.strokeColor = tint.withAlphaComponent(0.8)
        button.lineWidth = 3
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        button.addChild(label)
    }

    func layout(viewSize: CGSize, insets: UIEdgeInsets = .zero) {
        let hw = viewSize.width / 2 - insets.right
        let hh = viewSize.height / 2 - insets.bottom
        let inset: CGFloat = 52
        secondaryButton.position = CGPoint(x: hw - inset - 6, y: -hh + inset + 40)
        primaryButton.position = CGPoint(x: hw - inset - 104, y: -hh + inset)
    }

    func setLabels(hasBall: Bool) {
        primaryLabel.text = hasBall ? "PASS" : "SWITCH"
        secondaryLabel.text = hasBall ? "SHOOT" : "TACKLE"
    }

    // MARK: Edge-triggered actions

    func consumePrimary() -> Bool {
        defer { pendingPrimary = false }
        return pendingPrimary
    }

    func consumeSecondary() -> Bool {
        defer { pendingSecondary = false }
        return pendingSecondary
    }

    func triggerPrimary() { pendingPrimary = true }
    func triggerSecondary() { pendingSecondary = true }
    func setKeyboardVector(_ v: CGVector) { keyVector = v.limited(to: 1) }

    // MARK: Touch routing (locations are converted into the space of this node)

    /// Returns true when the touch was consumed by the stick or a button.
    func touchBegan(_ touch: UITouch) -> Bool {
        let p = touch.location(in: self)
        if primaryButton.contains(p) {
            pendingPrimary = true
            flash(primaryButton)
            return true
        }
        if secondaryButton.contains(p) {
            pendingSecondary = true
            flash(secondaryButton)
            return true
        }
        if p.x < 0 && stickTouch == nil {
            stickTouch = touch
            stickOrigin = p
            stickBase.position = p
            stickKnob.position = p
            stickBase.isHidden = false
            stickKnob.isHidden = false
            stickVector = .zero
            return true
        }
        return false
    }

    func touchMoved(_ touch: UITouch) {
        guard touch === stickTouch else { return }
        let p = touch.location(in: self)
        var v = p - stickOrigin
        let len = v.length
        if len > stickRadius { v = v * (stickRadius / len) }
        stickKnob.position = stickOrigin + v
        stickVector = v / stickRadius
    }

    func touchEnded(_ touch: UITouch) {
        guard touch === stickTouch else { return }
        stickTouch = nil
        stickVector = .zero
        stickBase.isHidden = true
        stickKnob.isHidden = true
    }

    private func flash(_ button: SKShapeNode) {
        button.removeAllActions()
        button.setScale(0.88)
        button.run(SKAction.scale(to: 1, duration: 0.12))
    }
}
