import SpriteKit

/// Score / clock strip, formation toggle, and the big centre message. Child of the camera.
final class HUD: SKNode {
    private let panel = SKShapeNode(rectOf: CGSize(width: 320, height: 58), cornerRadius: 14)
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let clockLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    let formationButton = SKShapeNode(rectOf: CGSize(width: 128, height: 38), cornerRadius: 10)
    private let formationLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let subMessageLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    override init() {
        super.init()
        zPosition = 90

        panel.fillColor = SKColor.black.withAlphaComponent(0.45)
        panel.strokeColor = SKColor.white.withAlphaComponent(0.25)
        panel.lineWidth = 1.5

        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: 0, y: 8)

        clockLabel.fontSize = 13
        clockLabel.fontColor = SKColor.white.withAlphaComponent(0.8)
        clockLabel.verticalAlignmentMode = .center
        clockLabel.position = CGPoint(x: 0, y: -14)

        panel.addChild(scoreLabel)
        panel.addChild(clockLabel)

        formationButton.fillColor = SKColor.black.withAlphaComponent(0.45)
        formationButton.strokeColor = SKColor.white.withAlphaComponent(0.4)
        formationButton.lineWidth = 1.5
        formationLabel.fontSize = 13
        formationLabel.fontColor = .white
        formationLabel.verticalAlignmentMode = .center
        formationButton.addChild(formationLabel)

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
        addChild(messageLabel)
        addChild(subMessageLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(viewSize: CGSize, insets: UIEdgeInsets = .zero) {
        let hw = viewSize.width / 2 - insets.right
        let hh = viewSize.height / 2 - insets.top
        panel.position = CGPoint(x: 0, y: hh - 44)
        formationButton.position = CGPoint(x: hw - 52 - 64, y: hh - 44)
    }

    func update(home: String, away: String, score: [Int], clock: TimeInterval, half: Int) {
        scoreLabel.text = "\(home)  \(score[0]) - \(score[1])  \(away)"
        let total = Int(clock.rounded(.up))
        let minutes = total / 60
        let seconds = total % 60
        let pad = seconds < 10 ? "0" : ""
        let halfName = half == 1 ? "1ST" : "2ND"
        clockLabel.text = "\(halfName) HALF   \(minutes):\(pad)\(seconds)"
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
