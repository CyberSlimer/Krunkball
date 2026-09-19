import SpriteKit

enum PlayerState { case active, tackling, recovering, down }
enum Highlight { case none, controlled, carrier }

/// One athlete on the deck. Movement is integrated by the scene; this node owns its
/// state machine (tackle lunge -> recovery, knockdowns) and its look.
final class PlayerNode: SKNode {
    let team: Int
    let squadIndex: Int
    let stats: PlayerStats
    let isGoalie: Bool

    var velocity = CGVector.zero
    var facing: CGFloat = 0
    var state: PlayerState = .active
    var stateTimer: TimeInterval = 0
    var tackleCooldown: TimeInterval = 0
    var tackleHitPending = false      // true during a lunge until it connects with someone
    var pickupDelay: TimeInterval = 0
    var thinkTimer: TimeInterval = 0  // AI decision throttle
    var protection: TimeInterval = 0  // cannot be tackled while > 0 (keeper just caught the ball)

    var maxSpeed: CGFloat { Tuning.baseSpeed + CGFloat(stats.speed) * Tuning.speedPerStat }
    var isDown: Bool { state == .down }

    private let ring = SKShapeNode(circleOfRadius: Tuning.playerRadius + 6)
    private let body = SKShapeNode(circleOfRadius: Tuning.playerRadius)
    private let inner = SKShapeNode(circleOfRadius: Tuning.playerRadius * 0.55)
    private let facingPivot = SKNode()
    private let numberLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    init(team: Int, squadIndex: Int, stats: PlayerStats, isGoalie: Bool, primary: SKColor, secondary: SKColor) {
        self.team = team
        self.squadIndex = squadIndex
        self.stats = stats
        self.isGoalie = isGoalie
        super.init()

        ring.fillColor = .clear
        ring.strokeColor = .clear
        ring.lineWidth = 3
        ring.isHidden = true
        ring.zPosition = 0

        body.fillColor = primary
        body.strokeColor = SKColor.black.withAlphaComponent(0.6)
        body.lineWidth = 2
        body.zPosition = 1

        inner.fillColor = isGoalie ? SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : secondary
        inner.strokeColor = .clear
        inner.zPosition = 2

        let tick = SKShapeNode(rectOf: CGSize(width: 10, height: 6), cornerRadius: 2)
        tick.fillColor = SKColor.white.withAlphaComponent(0.9)
        tick.strokeColor = .clear
        tick.position = CGPoint(x: Tuning.playerRadius - 3, y: 0)
        facingPivot.addChild(tick)
        facingPivot.zPosition = 3

        numberLabel.text = isGoalie ? "K" : "\(squadIndex)"
        numberLabel.fontSize = 12
        numberLabel.fontColor = isGoalie ? SKColor.black : SKColor.white.withAlphaComponent(0.9)
        numberLabel.verticalAlignmentMode = .center
        numberLabel.horizontalAlignmentMode = .center
        numberLabel.zPosition = 4

        addChild(ring)
        addChild(body)
        addChild(inner)
        addChild(facingPivot)
        addChild(numberLabel)
        zPosition = 10
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setHighlight(_ h: Highlight) {
        switch h {
        case .none:
            ring.isHidden = true
        case .controlled:
            ring.isHidden = false
            ring.strokeColor = .white
        case .carrier:
            ring.isHidden = false
            ring.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        }
    }

    func beginTackle() {
        state = .tackling
        stateTimer = Tuning.tackleDuration
        tackleHitPending = true
        tackleCooldown = Tuning.tackleCooldown
        velocity = CGVector(angle: facing) * Tuning.tackleLungeSpeed
    }

    func knockDown(for duration: TimeInterval) {
        state = .down
        stateTimer = duration
        tackleHitPending = false
    }

    func resetState() {
        velocity = .zero
        state = .active
        stateTimer = 0
        tackleCooldown = 0
        tackleHitPending = false
        pickupDelay = 0
        protection = 0
        thinkTimer = 0
        refreshVisual()
    }

    /// Advance timers. Called every frame, even while play is frozen, so downed players get up.
    func tick(dt: TimeInterval) {
        tackleCooldown = max(0, tackleCooldown - dt)
        pickupDelay = max(0, pickupDelay - dt)
        protection = max(0, protection - dt)
        thinkTimer -= dt
        switch state {
        case .active:
            break
        case .tackling:
            stateTimer -= dt
            if stateTimer <= 0 {
                state = .recovering
                stateTimer = Tuning.tackleRecovery
                tackleHitPending = false
            }
        case .recovering, .down:
            stateTimer -= dt
            if stateTimer <= 0 { state = .active }
        }
        refreshVisual()
    }

    private func refreshVisual() {
        facingPivot.zRotation = facing
        switch state {
        case .active:
            body.alpha = 1; inner.alpha = 1
            xScale = 1; yScale = 1
        case .tackling:
            body.alpha = 1; inner.alpha = 1
            xScale = 1.15; yScale = 1.15
        case .recovering:
            body.alpha = 0.85; inner.alpha = 0.85
            xScale = 1; yScale = 1
        case .down:
            body.alpha = 0.5; inner.alpha = 0.5
            xScale = 1.1; yScale = 0.7
        }
    }
}
