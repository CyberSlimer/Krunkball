import SpriteKit

/// What a player wants to do this frame. Produced by the touch controls for the human-controlled
/// athlete and by the AI for everyone else, then applied uniformly by the scene.
struct PlayerIntent {
    var move = CGVector.zero      // desired direction, magnitude 0...1
    var aim = CGVector.zero       // steering for passes / shots
    var tackle = false
    var pass = false
    var shoot = false
    var switchPlayer = false
}

/// The match itself: arena, 2 x 10 athletes, ball, camera, HUD and touch controls.
/// Simulation is hand-rolled kinematics (no SKPhysics) so the feel stays deterministic and tunable.
final class MatchScene: SKScene {
    enum Phase {
        case kickoff(TimeInterval)
        case playing
        case goal(TimeInterval)
        case halfTime(TimeInterval)
        case fullTime
    }

    let teams: [TeamData]
    let humanTeam = 0

    let world = SKNode()
    let cam = SKCameraNode()
    var players: [[PlayerNode]] = [[], []]
    let ball = BallNode()
    let controls = TouchControls()
    let hud = HUD()

    var score = [0, 0]
    /// +1 means the team attacks towards +x, -1 towards -x. Swapped at half time.
    var attackDir: [CGFloat] = [1, -1]
    var half = 1
    var clock: TimeInterval = Tuning.halfLength
    var phase: Phase = .kickoff(Tuning.kickoffFreeze)
    var formationIndex = [0, 0]
    /// The human athlete that receives stick input when the human side is not carrying the ball.
    weak var selected: PlayerNode?
    var lastPossessingTeam: Int?
    /// Players assigned to press the ball this frame (see MatchScene+AI).
    var chaserIDs = Set<ObjectIdentifier>()

    /// Match statistics per team, for the balance benchmark and (later) the post-match screen.
    struct TeamStats { var shots = 0, saves = 0, tacklesWon = 0, tacklesLost = 0 }
    var stats = [TeamStats(), TeamStats()]

    /// Screen-edge insets (notch / Dynamic Island / home indicator) in view points. Set by the host controller.
    var safeInsets = UIEdgeInsets.zero {
        didSet { layoutOverlay() }
    }
    /// Debug: `KRUNKBALL_AUTOPILOT=1` in the environment hands the human side to the AI, for balance testing.
    /// Tests flip it directly.
    var autopilot: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["KRUNKBALL_AUTOPILOT"] != nil
        #else
        return false
        #endif
    }()

    private var lastTime: TimeInterval = 0
    private var pressedKeys = Set<UIKeyboardHIDUsage>()

    var isPlaying: Bool {
        if case .playing = phase { return true }
        return false
    }

    /// The athlete the human is steering right now: the carrier if the human side has the ball, else `selected`.
    var controlledPlayer: PlayerNode? {
        if let c = ball.carrier, c.team == humanTeam { return c }
        return selected
    }

    /// The athlete that actually takes stick input this frame (nobody under autopilot).
    var humanDriven: PlayerNode? { autopilot ? nil : controlledPlayer }

    var scoreline: String { "\(teams[0].shortName) \(score[0]) - \(score[1]) \(teams[1].shortName)" }

    func formation(for team: Int) -> Formation { Formation.all[formationIndex[team]] }
    func goalCenter(for team: Int) -> CGPoint { CGPoint(x: attackDir[team] * Tuning.fieldLength / 2, y: 0) }
    func ownGoalCenter(for team: Int) -> CGPoint { CGPoint(x: -attackDir[team] * Tuning.fieldLength / 2, y: 0) }

    // MARK: Lifecycle

    init(teams: [TeamData], size: CGSize) {
        self.teams = teams
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.08, blue: 0.1, alpha: 1)
        addChild(world)
        buildArena()
        buildTeams()
        world.addChild(ball)

        camera = cam
        addChild(cam)
        cam.addChild(controls)
        cam.addChild(hud)
        layoutOverlay()
        hud.setFormation(formation(for: humanTeam).name)

        resetForKickoff()
        hud.showMessage("KICK OFF", sub: "\(teams[0].name)  vs  \(teams[1].name)")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutOverlay()
    }

    /// Camera zoom follows the view height so the same slice of arena is visible on every device.
    /// Camera children (HUD, controls) render in screen points regardless of the camera scale.
    private func layoutOverlay() {
        guard size.height > 0 else { return }
        cam.setScale(Tuning.cameraVisibleHeight / size.height)
        controls.layout(viewSize: size, insets: safeInsets)
        hud.layout(viewSize: size, insets: safeInsets)
    }

    // MARK: Build

    private func buildArena() {
        let L = Tuning.fieldLength
        let W = Tuning.fieldWidth

        let turf = SKShapeNode(rectOf: CGSize(width: L, height: W))
        turf.fillColor = SKColor(red: 0.16, green: 0.2, blue: 0.24, alpha: 1)
        turf.strokeColor = .clear
        turf.zPosition = 0
        world.addChild(turf)

        // Subtle stripes so movement reads even with a plain fill
        var x = -L / 2
        var light = false
        while x < L / 2 {
            if light {
                let stripe = SKShapeNode(rectOf: CGSize(width: 100, height: W))
                stripe.position = CGPoint(x: x + 50, y: 0)
                stripe.fillColor = SKColor.white.withAlphaComponent(0.03)
                stripe.strokeColor = .clear
                stripe.zPosition = 0.5
                world.addChild(stripe)
            }
            light.toggle()
            x += 100
        }

        // Markings
        let path = CGMutablePath()
        path.addRect(CGRect(x: -L / 2, y: -W / 2, width: L, height: W))
        path.move(to: CGPoint(x: 0, y: -W / 2))
        path.addLine(to: CGPoint(x: 0, y: W / 2))
        path.addEllipse(in: CGRect(x: -120, y: -120, width: 240, height: 240))
        path.addRect(CGRect(x: -L / 2, y: -260, width: 260, height: 520))
        path.addRect(CGRect(x: L / 2 - 260, y: -260, width: 260, height: 520))
        let lines = SKShapeNode(path: path)
        lines.strokeColor = SKColor.white.withAlphaComponent(0.35)
        lines.lineWidth = 3
        lines.fillColor = .clear
        lines.zPosition = 1
        world.addChild(lines)

        // Walls (the ball rebounds off these)
        let wall = SKShapeNode(rectOf: CGSize(width: L + 24, height: W + 24))
        wall.strokeColor = SKColor(white: 0.62, alpha: 1)
        wall.lineWidth = 14
        wall.fillColor = .clear
        wall.zPosition = 2
        world.addChild(wall)

        // Goals: a net box behind each end line, with the wall segment in front cut away
        for side: CGFloat in [-1, 1] {
            let mouth = SKShapeNode(rectOf: CGSize(width: 40, height: Tuning.goalHalfWidth * 2))
            mouth.position = CGPoint(x: side * (L / 2 + 2), y: 0)
            mouth.fillColor = turf.fillColor
            mouth.strokeColor = .clear
            mouth.zPosition = 3
            world.addChild(mouth)

            let net = SKShapeNode(rectOf: CGSize(width: Tuning.goalDepth, height: Tuning.goalHalfWidth * 2))
            net.position = CGPoint(x: side * (L / 2 + Tuning.goalDepth / 2 + 6), y: 0)
            net.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
            net.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            net.lineWidth = 4
            net.zPosition = 4
            world.addChild(net)
        }
    }

    private func buildTeams() {
        for t in 0..<2 {
            let data = teams[t]
            for (i, stats) in data.players.enumerated() {
                let p = PlayerNode(team: t, squadIndex: i, stats: stats, isGoalie: i == 0,
                                   primary: data.primary, secondary: data.secondary)
                world.addChild(p)
                players[t].append(p)
            }
        }
    }

    // MARK: Phases

    func resetForKickoff() {
        ball.position = .zero
        ball.velocity = .zero
        ball.state = .loose
        ball.carrier = nil
        ball.lastThrower = nil
        ball.airTime = 0
        ball.throwerImmunity = 0
        ball.setAirborne(false)
        lastPossessingTeam = nil

        for t in 0..<2 {
            let dir = attackDir[t]
            for p in players[t] {
                p.resetState()
                p.facing = dir > 0 ? 0 : .pi
                if p.isGoalie {
                    p.position = ownGoalCenter(for: t) + CGVector(dx: dir * 40, dy: 0)
                } else {
                    let slot = formation(for: t).slots[p.squadIndex - 1]
                    p.position = CGPoint(x: dir * (-260 + slot.dx * 0.7), y: slot.dy * 0.85)
                }
                p.setHighlight(.none)
            }
        }

        selected = players[humanTeam]
            .filter { !$0.isGoalie }
            .min { $0.position.distance(to: .zero) < $1.position.distance(to: .zero) }
        cam.position = .zero
        phase = .kickoff(Tuning.kickoffFreeze)
    }

    func restartMatch() {
        score = [0, 0]
        half = 1
        clock = Tuning.halfLength
        attackDir = [1, -1]
        resetForKickoff()
        hud.showMessage("KICK OFF", sub: "\(teams[0].name)  vs  \(teams[1].name)")
    }

    private func advancePhase(_ dt: TimeInterval) {
        switch phase {
        case .kickoff(let t):
            let remaining = t - dt
            if remaining <= 0 {
                phase = .playing
                hud.hideMessage()
            } else {
                phase = .kickoff(remaining)
            }
        case .playing:
            clock = max(0, clock - dt)
            if clock == 0 {
                if half == 1 {
                    phase = .halfTime(Tuning.halfTimePause)
                    hud.showMessage("HALF TIME", sub: scoreline)
                } else {
                    phase = .fullTime
                    #if DEBUG
                    NSLog("KRUNK fulltime score=%d-%d", score[0], score[1])
                    #endif
                    hud.showMessage("FULL TIME", sub: "\(scoreline)   -   tap to play again")
                }
            }
        case .goal(let t):
            let remaining = t - dt
            if remaining <= 0 {
                resetForKickoff()
                hud.hideMessage()
            } else {
                phase = .goal(remaining)
            }
        case .halfTime(let t):
            let remaining = t - dt
            if remaining <= 0 {
                half = 2
                clock = Tuning.halfLength
                attackDir = attackDir.map { -$0 }
                resetForKickoff()
                hud.showMessage("2ND HALF")
            } else {
                phase = .halfTime(remaining)
            }
        case .fullTime:
            break
        }
    }

    func scoreGoal(for team: Int) {
        score[team] += 1
        #if DEBUG
        NSLog("KRUNK goal team=%d half=%d clock=%.1f score=%d-%d", team, half, clock, score[0], score[1])
        #endif
        ball.velocity = .zero
        ball.state = .loose
        ball.carrier = nil
        ball.setAirborne(false)
        phase = .goal(Tuning.goalCelebration)
        hud.showMessage("GOAL!", sub: "\(teams[team].name)   \(scoreline)")
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval = lastTime == 0 ? 1.0 / 60.0 : min(currentTime - lastTime, 1.0 / 30.0)
        lastTime = currentTime

        advancePhase(dt)
        for team in players {
            for p in team { p.tick(dt: dt) }
        }

        if isPlaying {
            ensureSelection()
            runPlayers(dt)
            resolveContacts()
            updateBall(dt)
        } else {
            // Discard taps that arrive while play is frozen so they do not fire on the first live frame.
            _ = controls.consumePrimary()
            _ = controls.consumeSecondary()
        }

        updateHighlights()
        updateCamera(dt)
        let humanHasBall = ball.carrier != nil && ball.carrier?.team == humanTeam
        controls.setLabels(hasBall: humanHasBall)
        hud.update(home: teams[0].shortName, away: teams[1].shortName, score: score, clock: clock, half: half)
    }

    private func runPlayers(_ dt: TimeInterval) {
        prepareAI()
        let human = humanDriven
        // Two phases: every athlete decides from the same frame-start snapshot, then everyone moves.
        // Deciding and moving in one pass hands whichever team is processed second a real edge (it
        // reads the other side's already-updated positions), which showed up as a 2:1 scoring bias.
        var decisions: [(PlayerNode, PlayerIntent)] = []
        decisions.reserveCapacity(20)
        for team in players {
            for p in team {
                decisions.append((p, (p === human) ? humanIntent() : aiIntent(for: p)))
            }
        }
        for (p, intent) in decisions {
            apply(intent, to: p, dt: dt)
        }
    }

    private func humanIntent() -> PlayerIntent {
        var intent = PlayerIntent()
        intent.move = controls.moveVector
        intent.aim = intent.move
        let hasBall = ball.carrier != nil && ball.carrier === controlledPlayer
        if controls.consumePrimary() {
            if hasBall { intent.pass = true } else { intent.switchPlayer = true }
        }
        if controls.consumeSecondary() {
            if hasBall { intent.shoot = true } else { intent.tackle = true }
        }
        return intent
    }

    private func apply(_ intent: PlayerIntent, to p: PlayerNode, dt: TimeInterval) {
        let fdt = CGFloat(dt)
        switch p.state {
        case .active:
            let mag = min(1, intent.move.length)
            let target = intent.move.normalized * (p.maxSpeed * mag)
            let delta = target - p.velocity
            let step = Tuning.acceleration * fdt
            p.velocity = delta.length <= step ? target : p.velocity + delta.normalized * step
            if mag > 0.15 { p.facing = intent.move.angle }

            if intent.switchPlayer { cycleSelection() }
            if p === ball.carrier {
                if intent.shoot {
                    shoot(from: p, aim: intent.aim)
                } else if intent.pass {
                    pass(from: p, aim: intent.aim)
                }
            } else if intent.tackle && p.tackleCooldown <= 0 {
                p.beginTackle()
            }
        case .tackling:
            break   // the lunge velocity was set when the tackle began
        case .recovering, .down:
            p.velocity = p.velocity * exp(-Tuning.downedDrag * fdt)
        }
        p.position += p.velocity * fdt
        clampToField(p)
    }

    private func clampToField(_ p: PlayerNode) {
        let r = Tuning.playerRadius
        p.position.x = clamp(p.position.x, -Tuning.fieldLength / 2 + r, Tuning.fieldLength / 2 - r)
        p.position.y = clamp(p.position.y, -Tuning.fieldWidth / 2 + r, Tuning.fieldWidth / 2 - r)
    }

    /// Push overlapping bodies apart and land any pending tackle lunges.
    private func resolveContacts() {
        let all = players[0] + players[1]
        let minDist = Tuning.playerRadius * 2
        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                let a = all[i]
                let b = all[j]
                let d = b.position - a.position
                let dist = d.length
                guard dist > 0.001, dist < minDist + Tuning.tackleReach else { continue }
                let n = d / dist
                if dist < minDist {
                    let push = (minDist - dist) / 2
                    a.position = a.position - n * push
                    b.position = b.position + n * push
                }
                guard a.team != b.team else { continue }
                let aLunging = a.state == .tackling && a.tackleHitPending && !b.isDown && b.protection <= 0
                let bLunging = b.state == .tackling && b.tackleHitPending && !a.isDown && a.protection <= 0
                if aLunging && bLunging {
                    // Head-on: neither side gets to be "the tackler" by virtue of list order.
                    if Bool.random() { resolveTackle(tackler: a, victim: b) } else { resolveTackle(tackler: b, victim: a) }
                } else if aLunging {
                    resolveTackle(tackler: a, victim: b)
                } else if bLunging {
                    resolveTackle(tackler: b, victim: a)
                }
            }
        }
    }

    private func updateHighlights() {
        let ctrl = controlledPlayer
        for team in players {
            for p in team {
                if p === ctrl {
                    p.setHighlight(.controlled)
                } else if p === ball.carrier {
                    p.setHighlight(.carrier)
                } else {
                    p.setHighlight(.none)
                }
            }
        }
    }

    private func updateCamera(_ dt: TimeInterval) {
        var target = ball.position
        if let c = ball.carrier {
            target = target + c.velocity * 0.35
        } else {
            target = target + ball.velocity * 0.2
        }
        let k = smoothFactor(rate: Tuning.cameraFollowRate, dt: CGFloat(dt))
        var pos = cam.position + (target - cam.position) * k

        // Keep the whole deck (goals included) out from under the notch / Dynamic Island: the visible
        // edge on each side is pulled in by that side's safe-area inset.
        let halfW = size.width / 2 * cam.xScale
        let halfH = size.height / 2 * cam.yScale
        let worldHalfL = Tuning.fieldLength / 2 + Tuning.wallMargin
        let worldHalfW = Tuning.fieldWidth / 2 + Tuning.wallMargin
        let minX = -worldHalfL - safeInsets.left * cam.xScale + halfW
        let maxX = worldHalfL + safeInsets.right * cam.xScale - halfW
        let minY = -worldHalfW - safeInsets.bottom * cam.yScale + halfH
        let maxY = worldHalfW + safeInsets.top * cam.yScale - halfH
        pos.x = minX < maxX ? clamp(pos.x, minX, maxX) : (minX + maxX) / 2
        pos.y = minY < maxY ? clamp(pos.y, minY, maxY) : (minY + maxY) / 2
        cam.position = pos
    }

    // MARK: Selection (which human athlete the stick drives)

    func ensureSelection() {
        if selected == nil {
            selectNearestToBall()
        } else if let s = selected, s.isDown, ball.carrier?.team != humanTeam {
            selectNearestToBall()
        }
    }

    func selectNearestToBall() {
        let candidate = players[humanTeam]
            .filter { !$0.isGoalie && !$0.isDown }
            .min { $0.position.distance(to: ball.position) < $1.position.distance(to: ball.position) }
        if let c = candidate { selected = c }
    }

    func cycleSelection() {
        let candidates = players[humanTeam]
            .filter { !$0.isDown }
            .sorted { $0.position.distance(to: ball.position) < $1.position.distance(to: ball.position) }
        guard !candidates.isEmpty else { return }
        if let s = selected, let idx = candidates.firstIndex(where: { $0 === s }) {
            selected = candidates[(idx + 1) % candidates.count]
        } else {
            selected = candidates[0]
        }
    }

    func cycleFormation() {
        formationIndex[humanTeam] = (formationIndex[humanTeam] + 1) % Formation.all.count
        hud.setFormation(formation(for: humanTeam).name)
    }

    // MARK: Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if case .fullTime = phase {
                restartMatch()
                return
            }
            let loc = touch.location(in: cam)
            if hud.formationButton.contains(loc) {
                cycleFormation()
                continue
            }
            _ = controls.touchBegan(touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.touchMoved(touch) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.touchEnded(touch) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { controls.touchEnded(touch) }
    }

    // MARK: Keyboard input (Simulator / iPad keyboard). Mirrors the original: WASD, G, H, J.

    func keyDown(_ code: UIKeyboardHIDUsage) -> Bool {
        switch code {
        case .keyboardW, .keyboardA, .keyboardS, .keyboardD,
             .keyboardUpArrow, .keyboardDownArrow, .keyboardLeftArrow, .keyboardRightArrow:
            pressedKeys.insert(code)
            refreshKeyVector()
            return true
        case .keyboardH, .keyboardSpacebar:
            if case .fullTime = phase { restartMatch() } else { controls.triggerPrimary() }
            return true
        case .keyboardG, .keyboardReturnOrEnter:
            controls.triggerSecondary()
            return true
        case .keyboardJ:
            cycleFormation()
            return true
        default:
            return false
        }
    }

    func keyUp(_ code: UIKeyboardHIDUsage) {
        pressedKeys.remove(code)
        refreshKeyVector()
    }

    private func refreshKeyVector() {
        var v = CGVector.zero
        if pressedKeys.contains(.keyboardW) || pressedKeys.contains(.keyboardUpArrow) { v.dy += 1 }
        if pressedKeys.contains(.keyboardS) || pressedKeys.contains(.keyboardDownArrow) { v.dy -= 1 }
        if pressedKeys.contains(.keyboardA) || pressedKeys.contains(.keyboardLeftArrow) { v.dx -= 1 }
        if pressedKeys.contains(.keyboardD) || pressedKeys.contains(.keyboardRightArrow) { v.dx += 1 }
        controls.setKeyboardVector(v)
    }
}
