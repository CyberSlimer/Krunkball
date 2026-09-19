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
    private let shadow = SKShapeNode(circleOfRadius: Tuning.ballRadius)

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
    }
}
