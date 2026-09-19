import SpriteKit

/// Movement stick on the left, two action buttons on the right.
/// Lives as a child of the camera, so its coordinate space is screen points centred on the view.
///
/// The prototype hid the stick until a finger landed on it, which made the game look like it had
/// no movement control at all — the two buttons were the only thing on screen. The stick is now
/// always drawn at a resting home position, brightens while held, and a one-off coach hint points
/// at it on the first kickoff.
final class TouchControls: SKNode {
    private(set) var stickVector = CGVector.zero
    private var keyVector = CGVector.zero
    private var pendingPrimary = false
    private var pendingSecondary = false

    private var stickTouch: UITouch?
    private var stickOrigin = CGPoint.zero
    private var stickHome = CGPoint.zero
    private let stickBase = SKShapeNode(circleOfRadius: Tuning.stickRadius)
    private let stickKnob = SKShapeNode(circleOfRadius: Tuning.stickKnobRadius)
    private let stickGlyph = SKShapeNode()
    private let stickLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    let primaryButton = SKShapeNode(circleOfRadius: Tuning.buttonRadius)
    let secondaryButton = SKShapeNode(circleOfRadius: Tuning.buttonRadius)
    private let primaryLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let secondaryLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let hint = SKNode()
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var hintTimer: TimeInterval = Tuning.coachHintDuration
    private var hintDismissed = false

    /// Half the view width, cached by `layout`, so a touch can be classed as "left side".
    private var halfWidth: CGFloat = 200

    /// True while a finger is on the stick. Used by the scene's idle-handoff timer.
    var isSteering: Bool { stickTouch != nil || keyVector.length > 0.01 }

    /// Stick input wins while a finger is down; otherwise fall back to the keyboard vector.
    /// Below the dead zone the stick reads as no input at all, so resting a thumb does not drift.
    var moveVector: CGVector {
        let raw = stickTouch != nil ? stickVector : keyVector
        let len = raw.length
        guard len > Tuning.stickDeadZone else { return .zero }
        // Rescale so the athlete still reaches full speed at the rim of the stick.
        let scaled = (len - Tuning.stickDeadZone) / (1 - Tuning.stickDeadZone)
        return raw.normalized * min(1, scaled)
    }

    override init() {
        super.init()
        zPosition = 100

        stickBase.fillColor = SKColor.white.withAlphaComponent(0.07)
        stickBase.strokeColor = SKColor.white.withAlphaComponent(0.30)
        stickBase.lineWidth = 2.5
        stickBase.zPosition = 0

        stickKnob.fillColor = SKColor.white.withAlphaComponent(0.26)
        stickKnob.strokeColor = SKColor.white.withAlphaComponent(0.55)
        stickKnob.lineWidth = 2
        stickKnob.zPosition = 2

        buildStickGlyph()
        stickGlyph.zPosition = 1

        stickLabel.text = "MOVE"
        stickLabel.fontSize = 11
        stickLabel.fontColor = SKColor.white.withAlphaComponent(0.55)
        stickLabel.verticalAlignmentMode = .center
        stickLabel.horizontalAlignmentMode = .center
        stickLabel.zPosition = 1

        configure(button: primaryButton, label: primaryLabel, tint: SKColor(red: 0.2, green: 0.6, blue: 1, alpha: 1))
        configure(button: secondaryButton, label: secondaryLabel, tint: SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1))
        setLabels(hasBall: false)
        buildHint()

        addChild(stickBase)
        addChild(stickGlyph)
        addChild(stickKnob)
        addChild(stickLabel)
        addChild(primaryButton)
        addChild(secondaryButton)
        addChild(hint)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A faint four-way arrow inside the stick base, so at a glance it reads as a movement control
    /// rather than decoration.
    private func buildStickGlyph() {
        let path = CGMutablePath()
        let a = Tuning.stickRadius * 0.62
        let b = Tuning.stickRadius * 0.40
        let tip = Tuning.stickRadius * 0.16
        for angle in [CGFloat(0), .pi / 2, .pi, .pi * 3 / 2] {
            let dir = CGVector(angle: angle)
            let side = dir.perpendicular
            let point = CGPoint(x: dir.dx * a, y: dir.dy * a)
            let leftBase = CGPoint(x: dir.dx * b + side.dx * tip, y: dir.dy * b + side.dy * tip)
            let rightBase = CGPoint(x: dir.dx * b - side.dx * tip, y: dir.dy * b - side.dy * tip)
            path.move(to: leftBase)
            path.addLine(to: point)
            path.addLine(to: rightBase)
            path.closeSubpath()
        }
        stickGlyph.path = path
        stickGlyph.fillColor = SKColor.white.withAlphaComponent(0.20)
        stickGlyph.strokeColor = .clear
    }

    private func buildHint() {
        let bubble = SKShapeNode(rectOf: CGSize(width: 224, height: 34), cornerRadius: 17)
        bubble.fillColor = SKColor(red: 0.2, green: 0.6, blue: 1, alpha: 0.85)
        bubble.strokeColor = SKColor.white.withAlphaComponent(0.8)
        bubble.lineWidth = 1.5
        hintLabel.text = "DRAG HERE TO MOVE"
        hintLabel.fontSize = 14
        hintLabel.fontColor = .white
        hintLabel.verticalAlignmentMode = .center
        hintLabel.horizontalAlignmentMode = .center
        bubble.addChild(hintLabel)
        hint.addChild(bubble)
        hint.zPosition = 3
        hint.alpha = 0
        hint.isHidden = true
    }

    private func configure(button: SKShapeNode, label: SKLabelNode, tint: SKColor) {
        button.fillColor = tint.withAlphaComponent(0.30)
        button.strokeColor = tint.withAlphaComponent(0.85)
        button.lineWidth = 3
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        button.addChild(label)
    }

    func layout(viewSize: CGSize, insets: UIEdgeInsets = .zero) {
        halfWidth = viewSize.width / 2
        let hw = viewSize.width / 2 - insets.right
        let hh = viewSize.height / 2 - insets.bottom
        let inset: CGFloat = 54
        secondaryButton.position = CGPoint(x: hw - inset - 6, y: -hh + inset + 44)
        primaryButton.position = CGPoint(x: hw - inset - 112, y: -hh + inset)

        stickHome = CGPoint(x: -viewSize.width / 2 + insets.left + Tuning.stickHomeInset.x,
                            y: -viewSize.height / 2 + insets.bottom + Tuning.stickHomeInset.y)
        if stickTouch == nil { parkStick() }
        stickLabel.position = CGPoint(x: stickHome.x, y: stickHome.y - Tuning.stickRadius - 14)
        hint.position = CGPoint(x: stickHome.x + 150, y: stickHome.y + Tuning.stickRadius + 26)
    }

    private func parkStick() {
        stickBase.position = stickHome
        stickGlyph.position = stickHome
        stickKnob.position = stickHome
        stickBase.strokeColor = SKColor.white.withAlphaComponent(0.30)
        stickKnob.fillColor = SKColor.white.withAlphaComponent(0.26)
        stickGlyph.alpha = 1
        stickLabel.alpha = 1
    }

    func setLabels(hasBall: Bool) {
        primaryLabel.text = hasBall ? "PASS" : "SWITCH"
        secondaryLabel.text = hasBall ? "SHOOT" : "TACKLE"
    }

    /// Show the coach hint until the player either drags the stick or the timer runs out.
    func tick(dt: TimeInterval, showHint: Bool) {
        guard !hintDismissed else { return }
        if showHint && hint.isHidden {
            hint.isHidden = false
            hint.alpha = 0
            hint.removeAllActions()
            hint.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 1, duration: 0.45),
                SKAction.fadeAlpha(to: 0.45, duration: 0.45),
            ])))
        }
        guard !hint.isHidden else { return }
        hintTimer -= dt
        if hintTimer <= 0 { dismissHint() }
    }

    func dismissHint() {
        guard !hintDismissed else { return }
        hintDismissed = true
        hint.removeAllActions()
        hint.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.3), SKAction.hide()]))
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

    func setKeyboardVector(_ v: CGVector) {
        keyVector = v.limited(to: 1)
        if keyVector.length > 0.01 { dismissHint() }
    }

    // MARK: Touch routing (locations are converted into the space of this node)

    /// Returns true when the touch was consumed by the stick or a button.
    func touchBegan(_ touch: UITouch) -> Bool {
        let p = touch.location(in: self)
        if hitTest(primaryButton, p) {
            pendingPrimary = true
            flash(primaryButton)
            return true
        }
        if hitTest(secondaryButton, p) {
            pendingSecondary = true
            flash(secondaryButton)
            return true
        }
        // Anywhere on the left side of the screen starts a drag; the stick jumps to the finger so
        // there is no need to hit the drawn circle exactly.
        let leftEdge = -halfWidth + halfWidth * 2 * Tuning.stickDragLimit
        if p.x < leftEdge && stickTouch == nil {
            stickTouch = touch
            stickOrigin = p
            stickBase.position = p
            stickGlyph.position = p
            stickKnob.position = p
            stickBase.strokeColor = SKColor.white.withAlphaComponent(0.55)
            stickKnob.fillColor = SKColor.white.withAlphaComponent(0.45)
            stickGlyph.alpha = 0.45
            stickVector = .zero
            dismissHint()
            return true
        }
        return false
    }

    /// Generous circular hit area: the drawn radius plus a margin, since fingers are not precise.
    private func hitTest(_ button: SKShapeNode, _ p: CGPoint) -> Bool {
        let d = CGVector(dx: p.x - button.position.x, dy: p.y - button.position.y)
        return d.length <= Tuning.buttonRadius + 12
    }

    func touchMoved(_ touch: UITouch) {
        guard touch === stickTouch else { return }
        let p = touch.location(in: self)
        var v = CGVector(dx: p.x - stickOrigin.x, dy: p.y - stickOrigin.y)
        let len = v.length
        if len > Tuning.stickRadius { v = v * (Tuning.stickRadius / len) }
        stickKnob.position = CGPoint(x: stickOrigin.x + v.dx, y: stickOrigin.y + v.dy)
        stickVector = v / Tuning.stickRadius
    }

    func touchEnded(_ touch: UITouch) {
        guard touch === stickTouch else { return }
        stickTouch = nil
        stickVector = .zero
        parkStick()
    }

    private func flash(_ button: SKShapeNode) {
        button.removeAllActions()
        button.setScale(0.88)
        button.run(SKAction.scale(to: 1, duration: 0.12))
    }
}
