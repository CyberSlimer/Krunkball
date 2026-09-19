import SpriteKit

final class BallNode: SKNode {
    enum State { case loose, held, flight }

    var state: State = .loose
    var velocity = CGVector.zero
    weak var carrier: PlayerNode?
    weak var lastThrower: PlayerNode?
    var airTime: TimeInterval = 0          // remaining time before a thrown ball drops to the deck
    var throwerImmunity: TimeInterval = 0  // remaining time during which the thrower cannot catch it back

    private let shape = SKShapeNode(circleOfRadius: Tuning.ballRadius)
    private let seam = SKShapeNode()
    private let shadow = SKShapeNode(circleOfRadius: Tuning.ballRadius)
    /// Fading ghosts behind a thrown ball, so a fast pass reads as a line rather than a teleport.
    private var trail: [SKShapeNode] = []
    private var history: [CGPoint] = []
    private var spin: CGFloat = 0

    override init() {
        super.init()
        shadow.fillColor = SKColor.black.withAlphaComponent(0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -3)
        shadow.zPosition = 0

        shape.fillColor = SKColor(red: 1, green: 0.9, blue: 0.25, alpha: 1)
        shape.strokeColor = SKColor.black.withAlphaComponent(0.6)
        shape.lineWidth = 1.5
        shape.zPosition = 1

        // A seam so the spin is visible; a plain disc looks static however fast it is moving.
        let seamPath = CGMutablePath()
        seamPath.move(to: CGPoint(x: -Tuning.ballRadius * 0.8, y: 0))
        seamPath.addQuadCurve(to: CGPoint(x: Tuning.ballRadius * 0.8, y: 0),
                              control: CGPoint(x: 0, y: Tuning.ballRadius * 0.7))
        seam.path = seamPath
        seam.strokeColor = SKColor.black.withAlphaComponent(0.45)
        seam.lineWidth = 1.6
        seam.fillColor = .clear
        seam.zPosition = 2
        shape.addChild(seam)

        for i in 0..<6 {
            let ghost = SKShapeNode(circleOfRadius: Tuning.ballRadius * (0.85 - CGFloat(i) * 0.09))
            ghost.fillColor = SKColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.30 - CGFloat(i) * 0.045)
            ghost.strokeColor = .clear
            ghost.zPosition = 0.5
            ghost.isHidden = true
            trail.append(ghost)
            addChild(ghost)
        }

        addChild(shadow)
        addChild(shape)
        zPosition = 20
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAirborne(_ airborne: Bool) {
        shape.setScale(airborne ? 1.35 : 1.0)
        shadow.position = airborne ? CGPoint(x: 8, y: -8) : CGPoint(x: 3, y: -3)
        if !airborne { clearTrail() }
    }

    /// Spin the seam with travel and shuffle the trail one frame along. Called once per frame by
    /// the scene after the ball has been integrated.
    func updateVisuals(dt: TimeInterval) {
        spin += velocity.length * CGFloat(dt) * 0.035
        seam.zRotation = spin

        guard state == .flight else {
            if !history.isEmpty { clearTrail() }
            return
        }
        history.insert(position, at: 0)
        if history.count > trail.count + 1 { history.removeLast() }
        for (i, ghost) in trail.enumerated() {
            let index = i + 1
            if index < history.count {
                ghost.isHidden = false
                // Children are positioned in the ball's own space, which is untransformed.
                ghost.position = CGPoint(x: history[index].x - position.x,
                                         y: history[index].y - position.y)
            } else {
                ghost.isHidden = true
            }
        }
    }

    func clearTrail() {
        history.removeAll()
        for ghost in trail {
            ghost.isHidden = true
            ghost.position = .zero
        }
    }
}
