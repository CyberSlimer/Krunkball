import SpriteKit

/// Score / clock strip, possession pips, the controlled athlete's name card, the formation toggle
/// and the big centre message. Child of the camera, so everything here is in screen points.
final class HUD: SKNode {
    private let panel = SKShapeNode(rectOf: CGSize(width: 344, height: 52), cornerRadius: 12)
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let clockLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let homePip = SKShapeNode(circleOfRadius: 6)
    private let awayPip = SKShapeNode(circleOfRadius: 6)

    let formationButton = SKShapeNode(rectOf: CGSize(width: 128, height: 38), cornerRadius: 10)
    private let formationLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    /// Who you are driving and how much puff they have left — the two things you cannot read off
    /// the deck at a glance.
    private let nameCard = SKShapeNode(rectOf: CGSize(width: 190, height: 44), cornerRadius: 10)
    private let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let roleLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let staminaTrack = SKShapeNode(rectOf: CGSize(width: 150, height: 6), cornerRadius: 3)
    private let staminaFill = SKShapeNode(rectOf: CGSize(width: 150, height: 6), cornerRadius: 3)
    private let handoffLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let subMessageLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private var homeShort = "HOME"
    private var awayShort = "AWAY"
    private var lastName = ""

    override init() {
        super.init()
        zPosition = 90

        panel.fillColor = SKColor.black.withAlphaComponent(0.5)
        panel.strokeColor = SKColor.white.withAlphaComponent(0.22)
        panel.lineWidth = 1.5

        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: 0, y: 7)

        clockLabel.fontSize = 12
        clockLabel.fontColor = SKColor.white.withAlphaComponent(0.75)
        clockLabel.verticalAlignmentMode = .center
        clockLabel.position = CGPoint(x: 0, y: -14)

        // Possession pips either side of the scoreline: the lit one has the ball.
        for (pip, x) in [(homePip, CGFloat(-158)), (awayPip, CGFloat(158))] {
            pip.strokeColor = SKColor.white.withAlphaComponent(0.35)
            pip.lineWidth = 1.5
            pip.fillColor = .clear
            pip.position = CGPoint(x: x, y: 7)
            panel.addChild(pip)
        }

        panel.addChild(scoreLabel)
        panel.addChild(clockLabel)

        formationButton.fillColor = SKColor.black.withAlphaComponent(0.5)
        formationButton.strokeColor = SKColor.white.withAlphaComponent(0.4)
        formationButton.lineWidth = 1.5
        formationLabel.fontSize = 13
        formationLabel.fontColor = .white
        formationLabel.verticalAlignmentMode = .center
        formationButton.addChild(formationLabel)

        buildNameCard()

        messageLabel.fontSize = 48
        messageLabel.fontColor = .white
        messageLabel.verticalAlignmentMode = .center
        messageLabel.position = CGPoint(x: 0, y: 26)
        subMessageLabel.fontSize = 16
        subMessageLabel.fontColor = SKColor.white.withAlphaComponent(0.85)
        subMessageLabel.verticalAlignmentMode = .center
        subMessageLabel.position = CGPoint(x: 0, y: -16)
        messageLabel.isHidden = true
        subMessageLabel.isHidden = true

        addChild(panel)
        addChild(formationButton)
        addChild(nameCard)
        addChild(messageLabel)
        addChild(subMessageLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildNameCard() {
        nameCard.fillColor = SKColor.black.withAlphaComponent(0.5)
        nameCard.strokeColor = SKColor.white.withAlphaComponent(0.22)
        nameCard.lineWidth = 1.5

        nameLabel.fontSize = 14
        nameLabel.fontColor = .white
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -84, y: 10)

        roleLabel.fontSize = 10
        roleLabel.fontColor = SKColor.white.withAlphaComponent(0.6)
        roleLabel.verticalAlignmentMode = .center
        roleLabel.horizontalAlignmentMode = .right
        roleLabel.position = CGPoint(x: 84, y: 10)

        staminaTrack.fillColor = SKColor.white.withAlphaComponent(0.14)
        staminaTrack.strokeColor = .clear
        staminaTrack.position = CGPoint(x: 0, y: -9)

        staminaFill.fillColor = SKColor(red: 0.4, green: 0.9, blue: 0.5, alpha: 1)
        staminaFill.strokeColor = .clear
        staminaFill.position = CGPoint(x: 0, y: -9)

        handoffLabel.text = "AI IN CONTROL — MOVE TO TAKE OVER"
        handoffLabel.fontSize = 10
        handoffLabel.fontColor = SKColor(red: 1, green: 0.7, blue: 0.3, alpha: 1)
        handoffLabel.verticalAlignmentMode = .center
        handoffLabel.horizontalAlignmentMode = .center
        handoffLabel.position = CGPoint(x: 0, y: -26)
        handoffLabel.isHidden = true

        nameCard.addChild(nameLabel)
        nameCard.addChild(roleLabel)
        nameCard.addChild(staminaTrack)
        nameCard.addChild(staminaFill)
        nameCard.addChild(handoffLabel)
        nameCard.isHidden = true
    }

    func layout(viewSize: CGSize, insets: UIEdgeInsets = .zero) {
        let hw = viewSize.width / 2 - insets.right
        let hh = viewSize.height / 2 - insets.top
        // Tight against the top edge, so the controlled athlete's marker does not disappear behind
        // the panel when play is up against the top wall.
        panel.position = CGPoint(x: 0, y: hh - 32)
        formationButton.position = CGPoint(x: hw - 52 - 64, y: hh - 32)
        nameCard.position = CGPoint(x: -viewSize.width / 2 + insets.left + 116,
                                    y: hh - 36)
    }

    func setTeams(home: TeamData, away: TeamData) {
        homeShort = home.shortName
        awayShort = away.shortName
        homePip.strokeColor = home.primary
        awayPip.strokeColor = away.primary
    }

    /// One call per frame with everything that changes.
    func update(score: [Int], clock: TimeInterval, half: Int,
                controlled: PlayerNode?, possession: Int?, handedOff: Bool) {
        scoreLabel.text = "\(homeShort)  \(score[0]) - \(score[1])  \(awayShort)"
        let total = Int(clock.rounded(.up))
        let minutes = total / 60
        let seconds = total % 60
        let pad = seconds < 10 ? "0" : ""
        let halfName = half == 1 ? "1ST" : "2ND"
        clockLabel.text = "\(halfName) HALF   \(minutes):\(pad)\(seconds)"

        homePip.fillColor = possession == 0 ? homePip.strokeColor : .clear
        awayPip.fillColor = possession == 1 ? awayPip.strokeColor : .clear

        guard let p = controlled else {
            nameCard.isHidden = true
            return
        }
        nameCard.isHidden = false
        if p.stats.name != lastName {
            lastName = p.stats.name
            nameLabel.text = p.stats.name.uppercased()
            roleLabel.text = p.isGoalie ? "KEEPER" : p.stats.role.displayName
        }
        let s = max(0.02, min(1, p.stamina))
        staminaFill.xScale = s
        staminaFill.position = CGPoint(x: -75 * (1 - s), y: -9)
        staminaFill.fillColor = s > 0.5
            ? SKColor(red: 0.4, green: 0.9, blue: 0.5, alpha: 1)
            : (s > 0.25 ? SKColor(red: 0.95, green: 0.8, blue: 0.3, alpha: 1)
                        : SKColor(red: 0.95, green: 0.4, blue: 0.35, alpha: 1))
        handoffLabel.isHidden = !handedOff
    }

    func setFormation(_ name: String) {
        formationLabel.text = "FORM \(name)"
    }

    func showMessage(_ text: String, sub: String? = nil) {
        messageLabel.text = text
        messageLabel.isHidden = false
        messageLabel.removeAllActions()
        messageLabel.setScale(0.6)
        messageLabel.run(SKAction.scale(to: 1, duration: 0.25))
        subMessageLabel.text = sub ?? ""
        subMessageLabel.isHidden = sub == nil
    }

    func hideMessage() {
        messageLabel.isHidden = true
        subMessageLabel.isHidden = true
    }
}
