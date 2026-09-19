import SpriteKit

enum PlayerState { case active, tackling, recovering, down }
enum Highlight { case none, controlled, carrier }

/// One athlete on the deck. Movement is integrated by the scene; this node owns its
/// state machine (tackle lunge -> recovery, knockdowns), its stamina and its look.
///
/// The look is drawn from shapes rather than a sprite sheet: a helmet with a visor, shoulder
/// pads, a torso in the team kit, and limbs that swing on a stride cycle driven by how fast the
/// athlete is actually moving. Build follows the stats, so a strength-heavy blocker is visibly
/// broader than a speed-heavy runner.
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
    /// 1 fresh, 0 blown. Drains while sprinting, recovers while easing off.
    var stamina: CGFloat = 1

    /// Top speed from the speed stat, scaled by how much puff is left.
    var maxSpeed: CGFloat {
        let base = Tuning.baseSpeed + CGFloat(stats.speed) * Tuning.speedPerStat
        let fatigue = Tuning.staminaFloorSpeed + (1 - Tuning.staminaFloorSpeed) * stamina
        return base * fatigue
    }

    var isDown: Bool { state == .down }

    // MARK: Look

    /// Drawn size. Deliberately larger than `Tuning.playerRadius`, which stays the collision radius
    /// the sim was balanced around.
    private let r = Tuning.playerRadius * Tuning.playerVisualScale

    private let shadow = SKShapeNode()
    private let marker = SKShapeNode()          // selection ring at the feet
    private let bodyPivot = SKNode()            // everything that turns with `facing`
    private let torso = SKShapeNode()
    private let leftPad = SKShapeNode()
    private let rightPad = SKShapeNode()
    private let leftArm = SKShapeNode()
    private let rightArm = SKShapeNode()
    private let leftLeg = SKShapeNode()
    private let rightLeg = SKShapeNode()
    private let helmet = SKShapeNode()
    private let helmetStripe = SKShapeNode()
    private let visor = SKShapeNode()
    private let numberLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let staminaTrack = SKShapeNode()
    private let staminaFill = SKShapeNode()

    private var stridePhase: CGFloat = 0
    /// False while play is frozen (kickoff, goal, half time). Velocities are left untouched during a
    /// freeze, so without this the stride keeps running and stamina keeps draining off a stale value.
    private var live = true
    private let shoulderHalf: CGFloat
    private let hipHalf: CGFloat
    private var highlight: Highlight = .none

    init(team: Int, squadIndex: Int, stats: PlayerStats, isGoalie: Bool, kit: Kit) {
        self.team = team
        self.squadIndex = squadIndex
        self.stats = stats
        self.isGoalie = isGoalie

        let build = stats.build
        let r = Tuning.playerRadius * Tuning.playerVisualScale
        shoulderHalf = r * (0.58 + 0.22 * build)
        hipHalf = r * (0.40 + 0.12 * build)

        super.init()

        // A keeper wears the kit inverted, the way the original did, so you can find him at a glance.
        let jersey = isGoalie ? kit.trim.shaded(-0.25) : kit.primary
        let sleeve = isGoalie ? KitColor(1, 0.85, 0.2) : kit.secondary
        let trim = isGoalie ? KitColor(0.1, 0.1, 0.12) : kit.trim

        buildShadow()
        buildMarker()
        buildLimbs(sleeve: sleeve, trim: trim)
        buildTorso(jersey: jersey, sleeve: sleeve)
        buildHelmet(jersey: jersey, trim: trim)
        buildNumber(trim: trim)
        buildStaminaPip()

        // Order matters: legs under the torso, helmet over it, number on the jersey back.
        bodyPivot.addChild(leftLeg)
        bodyPivot.addChild(rightLeg)
        bodyPivot.addChild(leftArm)
        bodyPivot.addChild(rightArm)
        bodyPivot.addChild(torso)
        bodyPivot.addChild(numberLabel)
        bodyPivot.addChild(leftPad)
        bodyPivot.addChild(rightPad)
        bodyPivot.addChild(helmet)
        bodyPivot.addChild(helmetStripe)
        bodyPivot.addChild(visor)

        addChild(shadow)
        addChild(marker)
        addChild(bodyPivot)
        addChild(staminaTrack)
        addChild(staminaFill)
        zPosition = 10
        applyStride(swing: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Construction

    private func buildShadow() {
        shadow.path = CGPath(ellipseIn: CGRect(x: -r * 0.62, y: -r * 0.52,
                                               width: r * 1.24, height: r * 1.04), transform: nil)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.32)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 1.5, y: -3)
        shadow.zPosition = -1
    }

    private func buildMarker() {
        // A flattened ellipse at the feet rather than a ring around the body: it reads as a
        // selection marker instead of making the athlete look like a disc again.
        marker.path = CGPath(ellipseIn: CGRect(x: -r * 0.86, y: -r * 0.62,
                                               width: r * 1.72, height: r * 1.24), transform: nil)
        marker.fillColor = .clear
        marker.strokeColor = .clear
        marker.lineWidth = 3
        marker.zPosition = -0.5
        marker.isHidden = true
    }

    private func buildLimbs(sleeve: KitColor, trim: KitColor) {
        let armSize = CGSize(width: r * 0.46, height: r * 0.24)
        for arm in [leftArm, rightArm] {
            arm.path = CGPath(roundedRect: CGRect(origin: CGPoint(x: -armSize.width / 2, y: -armSize.height / 2),
                                                  size: armSize),
                              cornerWidth: armSize.height / 2, cornerHeight: armSize.height / 2, transform: nil)
            arm.fillColor = sleeve.color
            arm.strokeColor = SKColor.black.withAlphaComponent(0.45)
            arm.lineWidth = 1
            arm.zPosition = 0.5
        }
        let legSize = CGSize(width: r * 0.52, height: r * 0.30)
        for leg in [leftLeg, rightLeg] {
            leg.path = CGPath(roundedRect: CGRect(origin: CGPoint(x: -legSize.width / 2, y: -legSize.height / 2),
                                                  size: legSize),
                              cornerWidth: legSize.height / 2, cornerHeight: legSize.height / 2, transform: nil)
            leg.fillColor = trim.shaded(-0.55).color
            leg.strokeColor = SKColor.black.withAlphaComponent(0.5)
            leg.lineWidth = 1
            leg.zPosition = 0.2
        }
        leftArm.position = CGPoint(x: 0, y: shoulderHalf * 1.05)
        rightArm.position = CGPoint(x: 0, y: -shoulderHalf * 1.05)
        leftLeg.position = CGPoint(x: 0, y: hipHalf * 0.62)
        rightLeg.position = CGPoint(x: 0, y: -hipHalf * 0.62)
    }

    private func buildTorso(jersey: KitColor, sleeve: KitColor) {
        // Wedge: broad at the shoulders (towards the front), tapering to the hips.
        let front = r * 0.34
        let back = r * 0.56
        let path = CGMutablePath()
        path.move(to: CGPoint(x: front, y: -shoulderHalf * 0.78))
        path.addQuadCurve(to: CGPoint(x: front, y: shoulderHalf * 0.78),
                          control: CGPoint(x: front + r * 0.26, y: 0))
        path.addLine(to: CGPoint(x: -back * 0.35, y: shoulderHalf))
        path.addQuadCurve(to: CGPoint(x: -back, y: hipHalf * 0.7),
                          control: CGPoint(x: -back * 0.9, y: shoulderHalf * 0.9))
        path.addQuadCurve(to: CGPoint(x: -back, y: -hipHalf * 0.7),
                          control: CGPoint(x: -back - r * 0.14, y: 0))
        path.addQuadCurve(to: CGPoint(x: -back * 0.35, y: -shoulderHalf),
                          control: CGPoint(x: -back * 0.9, y: -shoulderHalf * 0.9))
        path.closeSubpath()
        torso.path = path
        torso.fillColor = jersey.color
        torso.strokeColor = SKColor.black.withAlphaComponent(0.6)
        torso.lineWidth = 1.6
        torso.zPosition = 1

        // Shoulder pads: the silhouette that says "full contact".
        let padRadius = r * 0.27
        for (pad, sign) in [(leftPad, CGFloat(1)), (rightPad, CGFloat(-1))] {
            pad.path = CGPath(ellipseIn: CGRect(x: -padRadius, y: -padRadius * 0.82,
                                                width: padRadius * 2, height: padRadius * 1.64), transform: nil)
            pad.fillColor = sleeve.color
            pad.strokeColor = SKColor.black.withAlphaComponent(0.55)
            pad.lineWidth = 1.2
            pad.position = CGPoint(x: r * 0.06, y: sign * shoulderHalf * 0.86)
            pad.zPosition = 2
        }
    }

    private func buildHelmet(jersey: KitColor, trim: KitColor) {
        let hr = r * 0.40
        helmet.path = CGPath(ellipseIn: CGRect(x: -hr * 1.02, y: -hr, width: hr * 2.04, height: hr * 2), transform: nil)
        helmet.fillColor = jersey.shaded(0.22).color
        helmet.strokeColor = SKColor.black.withAlphaComponent(0.65)
        helmet.lineWidth = 1.4
        helmet.position = CGPoint(x: r * 0.26, y: 0)
        helmet.zPosition = 3

        // Crest stripe front-to-back, so you can read which way an athlete is turned.
        let stripe = CGMutablePath()
        stripe.addRect(CGRect(x: -hr * 0.9, y: -hr * 0.16, width: hr * 1.8, height: hr * 0.32))
        helmetStripe.path = stripe
        helmetStripe.fillColor = trim.color
        helmetStripe.strokeColor = .clear
        helmetStripe.position = helmet.position
        helmetStripe.zPosition = 3.5

        // Visor across the front of the helmet.
        let v = CGMutablePath()
        v.addArc(center: .zero, radius: hr * 0.86, startAngle: -0.85, endAngle: 0.85, clockwise: false)
        visor.path = v
        visor.strokeColor = SKColor(red: 0.35, green: 0.85, blue: 1, alpha: 0.95)
        visor.lineWidth = hr * 0.42
        visor.lineCap = .round
        visor.fillColor = .clear
        visor.position = helmet.position
        visor.zPosition = 4
    }

    private func buildNumber(trim: KitColor) {
        // Matches the squad screen: the keeper is K, outfielders are their slot 1-9.
        numberLabel.text = isGoalie ? "K" : "\(squadIndex)"
        numberLabel.fontSize = r * 0.5
        numberLabel.fontColor = trim.color
        numberLabel.verticalAlignmentMode = .center
        numberLabel.horizontalAlignmentMode = .center
        numberLabel.position = CGPoint(x: -r * 0.22, y: 0)
        numberLabel.zRotation = -(CGFloat.pi / 2)  // reads down the back, so it is upright when running up-screen
        numberLabel.zPosition = 1.5
    }

    private func buildStaminaPip() {
        let w = r * 1.5
        let h = r * 0.18
        let rect = CGRect(x: -w / 2, y: -r * 1.15, width: w, height: h)
        staminaTrack.path = CGPath(roundedRect: rect, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
        staminaTrack.fillColor = SKColor.black.withAlphaComponent(0.5)
        staminaTrack.strokeColor = .clear
        staminaTrack.zPosition = 6
        staminaTrack.isHidden = true

        staminaFill.path = CGPath(roundedRect: rect, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
        staminaFill.fillColor = SKColor(red: 0.4, green: 0.9, blue: 0.5, alpha: 1)
        staminaFill.strokeColor = .clear
        staminaFill.zPosition = 6.5
        staminaFill.isHidden = true
        // Anchored left so scaling x reads as a bar draining.
        staminaFill.xScale = 1
    }

    // MARK: State

    func setHighlight(_ h: Highlight) {
        guard h != highlight else { return }
        highlight = h
        switch h {
        case .none:
            marker.strokeColor = .clear
            marker.isHidden = true
            staminaTrack.isHidden = true
            staminaFill.isHidden = true
        case .controlled:
            marker.isHidden = false
            marker.strokeColor = SKColor.white.withAlphaComponent(0.95)
            staminaTrack.isHidden = false
            staminaFill.isHidden = false
        case .carrier:
            marker.isHidden = false
            marker.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            staminaTrack.isHidden = true
            staminaFill.isHidden = true
        }
    }

    func beginTackle() {
        state = .tackling
        stateTimer = Tuning.tackleDuration
        tackleHitPending = true
        tackleCooldown = Tuning.tackleCooldown
        stamina = max(0, stamina - Tuning.staminaTackleCost)
        velocity = CGVector(angle: facing) * Tuning.tackleLungeSpeed
    }

    func knockDown(for duration: TimeInterval) {
        state = .down
        stateTimer = duration
        tackleHitPending = false
    }

    /// Back to a clean standing start. Stamina is deliberately left alone — the scene decides
    /// whether a restart is a full rest (a new half) or just a breather (after a goal).
    func resetState() {
        velocity = .zero
        state = .active
        stateTimer = 0
        tackleCooldown = 0
        tackleHitPending = false
        pickupDelay = 0
        protection = 0
        thinkTimer = 0
        stridePhase = 0
        live = true
        refreshVisual()
    }

    /// Give back some puff during a stoppage. `full` is a new half; anything else is a goal break.
    func restoreStamina(full: Bool) {
        stamina = full ? 1 : min(1, stamina + Tuning.staminaBreakRecovery)
    }

    /// Advance timers and stamina. Called every frame, even while play is frozen, so downed players
    /// get up and everyone gets their breath back at half time.
    func tick(dt: TimeInterval, live: Bool = true) {
        self.live = live
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
        updateStamina(dt: dt)
        advanceStride(dt: dt)
        refreshVisual()
    }

    /// Effort above the sprint threshold costs stamina; anything below it pays some back. A fast
    /// athlete is also a fitter one, so the speed stat softens the drain.
    private func updateStamina(dt: TimeInterval) {
        let fdt = CGFloat(dt)
        guard live else {
            // Frozen play: everyone gets their breath back rather than draining off a stale velocity.
            stamina = min(1, stamina + Tuning.staminaRecoverPerSecond * fdt)
            return
        }
        guard state != .down else {
            stamina = min(1, stamina + Tuning.staminaRecoverPerSecond * fdt * 1.4)
            return
        }
        let cap = Tuning.baseSpeed + CGFloat(stats.speed) * Tuning.speedPerStat
        let effort = cap > 0 ? min(1, velocity.length / cap) : 0
        if effort > Tuning.staminaSprintThreshold {
            let over = (effort - Tuning.staminaSprintThreshold) / max(0.01, 1 - Tuning.staminaSprintThreshold)
            let fitness = max(0.35, 1 - CGFloat(stats.speed) * Tuning.staminaPerEndurance)
            stamina = max(0, stamina - Tuning.staminaDrainPerSecond * over * fitness * fdt)
        } else {
            stamina = min(1, stamina + Tuning.staminaRecoverPerSecond * fdt)
        }
    }

    /// The stride advances with distance covered, not with time, so a walking athlete does not
    /// paddle its legs at sprint tempo.
    private func advanceStride(dt: TimeInterval) {
        guard live, state == .active || state == .recovering else { return }
        stridePhase += velocity.length * CGFloat(dt) * Tuning.runCycleRate
        if stridePhase > .pi * 2 { stridePhase -= .pi * 2 }
    }

    private func refreshVisual() {
        bodyPivot.zRotation = facing
        shadow.zRotation = 0

        let cap = Tuning.baseSpeed + CGFloat(stats.speed) * Tuning.speedPerStat
        let effort = live && cap > 0 ? min(1, velocity.length / cap) : 0

        switch state {
        case .active, .recovering:
            bodyPivot.xScale = 1
            bodyPivot.yScale = 1
            bodyPivot.alpha = state == .recovering ? 0.85 : 1
            shadow.alpha = 1
            applyStride(swing: sin(stridePhase) * Tuning.runCycleSwing * effort)
            // A small bob at speed sells the footfalls without a sprite sheet.
            let bob = 1 + 0.035 * sin(stridePhase * 2) * effort
            torso.yScale = bob
        case .tackling:
            // Dive: stretched along the facing direction, arms out in front, legs trailing.
            bodyPivot.xScale = 1.22
            bodyPivot.yScale = 0.88
            bodyPivot.alpha = 1
            shadow.alpha = 0.7
            torso.yScale = 1
            applyDive()
        case .down:
            bodyPivot.xScale = 1.14
            bodyPivot.yScale = 0.66
            bodyPivot.alpha = 0.55
            shadow.alpha = 0.5
            torso.yScale = 1
            applySprawl()
        }

        if !staminaFill.isHidden {
            staminaFill.xScale = max(0.02, stamina)
            staminaFill.position = CGPoint(x: -r * 0.75 * (1 - stamina), y: 0)
            staminaFill.fillColor = stamina > 0.5
                ? SKColor(red: 0.4, green: 0.9, blue: 0.5, alpha: 1)
                : (stamina > 0.25 ? SKColor(red: 0.95, green: 0.8, blue: 0.3, alpha: 1)
                                  : SKColor(red: 0.95, green: 0.4, blue: 0.35, alpha: 1))
        }
    }

    /// `swing` is the fore/aft offset of the leading leg, in points.
    private func applyStride(swing: CGFloat) {
        leftLeg.position = CGPoint(x: swing, y: hipHalf * 0.62)
        rightLeg.position = CGPoint(x: -swing, y: -hipHalf * 0.62)
        leftArm.position = CGPoint(x: -swing * 0.8, y: shoulderHalf * 1.05)
        rightArm.position = CGPoint(x: swing * 0.8, y: -shoulderHalf * 1.05)
        leftLeg.zRotation = 0
        rightLeg.zRotation = 0
        leftArm.zRotation = 0
        rightArm.zRotation = 0
    }

    private func applyDive() {
        let reach = r * 0.44
        leftArm.position = CGPoint(x: reach, y: shoulderHalf * 0.72)
        rightArm.position = CGPoint(x: reach, y: -shoulderHalf * 0.72)
        leftArm.zRotation = -0.25
        rightArm.zRotation = 0.25
        leftLeg.position = CGPoint(x: -r * 0.42, y: hipHalf * 0.5)
        rightLeg.position = CGPoint(x: -r * 0.42, y: -hipHalf * 0.5)
        leftLeg.zRotation = 0.2
        rightLeg.zRotation = -0.2
    }

    private func applySprawl() {
        leftArm.position = CGPoint(x: -r * 0.1, y: shoulderHalf * 1.35)
        rightArm.position = CGPoint(x: r * 0.1, y: -shoulderHalf * 1.35)
        leftArm.zRotation = 1.1
        rightArm.zRotation = -1.1
        leftLeg.position = CGPoint(x: -r * 0.5, y: hipHalf * 0.9)
        rightLeg.position = CGPoint(x: -r * 0.5, y: -hipHalf * 0.9)
        leftLeg.zRotation = 0.7
        rightLeg.zRotation = -0.7
    }
}
