import SpriteKit

// Team AI. Every athlete the human is not steering runs through `aiIntent(for:)` each frame.
// Movement is recomputed every frame; discrete decisions (tackle / pass / shoot) are throttled by
// each player's `thinkTimer` so the AI has human-ish reaction time rather than frame-perfect reflexes.
extension MatchScene {

    /// Decide, once per frame, which athletes on each side press the ball. Everyone else holds shape.
    func prepareAI() {
        chaserIDs.removeAll()
        let human = humanDriven
        for t in 0..<2 {
            let opponentHasBall = ball.carrier != nil && ball.carrier?.team != t
            let ballLoose = ball.carrier == nil
            guard opponentHasBall || ballLoose else { continue }
            let sorted = players[t]
                .filter { !$0.isGoalie && !$0.isDown && $0 !== human }
                .sorted { $0.position.distance(to: ball.position) < $1.position.distance(to: ball.position) }
            for p in sorted.prefix(Tuning.aiChasersPerTeam) {
                chaserIDs.insert(ObjectIdentifier(p))
            }
        }
    }

    func aiIntent(for p: PlayerNode) -> PlayerIntent {
        guard p.state == .active else { return PlayerIntent() }
        if p.isGoalie { return goalieIntent(for: p) }
        if ball.carrier === p { return carrierIntent(for: p) }

        if let c = ball.carrier, c.team != p.team {
            if chaserIDs.contains(ObjectIdentifier(p)) { return chaseIntent(for: p, target: c) }
            return holdIntent(for: p, defensive: true)
        }
        if ball.carrier == nil {
            if chaserIDs.contains(ObjectIdentifier(p)) {
                let predicted = ball.position + ball.velocity * 0.25
                return PlayerIntent(move: (predicted - p.position).normalized)
            }
            return holdIntent(for: p, defensive: false)
        }
        // A teammate has it: run the formation forward to offer options.
        return holdIntent(for: p, defensive: false)
    }

    // MARK: Shape

    /// Where this athlete should stand: their formation slot, anchored on the ball and dragged
    /// back towards their own goal when defending.
    func homePosition(for p: PlayerNode, defensive: Bool) -> CGPoint {
        let t = p.team
        let dir = attackDir[t]
        let slot = formation(for: t).slots[p.squadIndex - 1]
        let anchorX = ball.position.x * 0.55 + (defensive ? -dir * 140 : dir * 40)
        let anchorY = ball.position.y * 0.35
        let x = anchorX + dir * slot.dx * (defensive ? 0.75 : 1)
        let y = anchorY + slot.dy
        let m: CGFloat = 40
        return CGPoint(x: clamp(x, -Tuning.fieldLength / 2 + m, Tuning.fieldLength / 2 - m),
                       y: clamp(y, -Tuning.fieldWidth / 2 + m, Tuning.fieldWidth / 2 - m))
    }

    func holdIntent(for p: PlayerNode, defensive: Bool) -> PlayerIntent {
        var intent = PlayerIntent()
        let home = homePosition(for: p, defensive: defensive)
        let d = home - p.position
        let dist = d.length
        if dist > 12 { intent.move = d.normalized * min(1, dist / 80) }

        // Opportunistic hit if the opposing carrier wanders into range.
        if let c = ball.carrier, c.team != p.team, p.tackleCooldown <= 0,
           p.position.distance(to: c.position) < Tuning.playerRadius * 2 + 30 {
            intent.move = (c.position - p.position).normalized
            intent.tackle = true
        }
        return intent
    }

    // MARK: Pressing

    func chaseIntent(for p: PlayerNode, target c: PlayerNode) -> PlayerIntent {
        var intent = PlayerIntent()
        let lead = c.position + c.velocity * 0.2
        intent.move = (lead - p.position).normalized
        let dist = p.position.distance(to: c.position)
        if dist < Tuning.playerRadius * 2 + 34 && p.tackleCooldown <= 0 && p.thinkTimer <= 0 {
            p.thinkTimer = Tuning.aiThinkInterval
            intent.tackle = true
        }
        return intent
    }

    // MARK: Carrying

    func carrierIntent(for p: PlayerNode) -> PlayerIntent {
        var intent = PlayerIntent()
        let goal = goalCenter(for: p.team)
        let toGoal = goal - p.position
        let distGoal = toGoal.length
        var move = toGoal.normalized

        let opponents = players[1 - p.team].filter { !$0.isDown }
        let nearest = opponents.min { $0.position.distance(to: p.position) < $1.position.distance(to: p.position) }
        var pressure = CGFloat.greatestFiniteMagnitude
        if let o = nearest {
            let rel = o.position - p.position
            pressure = rel.length
            // Opponent close and roughly ahead: cut sideways around them.
            if pressure < 140 && rel.dot(move) > -0.2 * pressure {
                let side = move.perpendicular
                let sign: CGFloat = rel.dot(side) > 0 ? -1 : 1
                move = (move * 0.55 + side * sign).normalized
            }
        }
        intent.move = move
        intent.aim = move

        if p.thinkTimer <= 0 {
            p.thinkTimer = Tuning.aiThinkInterval
            let shootRange = Tuning.aiShootRange + CGFloat(p.stats.throwing) * 1.6
            let underPressure = pressure < Tuning.aiPressureDistance
            if distGoal < Tuning.aiCloseShotRange {
                // Point blank: let it fly.
                intent.shoot = true
            } else if underPressure {
                // Closed down: move it on if anyone is open, otherwise have a go if in range.
                if let t = openTeammate(for: p) {
                    intent.pass = true
                    intent.aim = (t.position - p.position).normalized
                } else if distGoal < shootRange {
                    intent.shoot = true
                }
            } else if distGoal < shootRange && CGFloat.random(in: 0...1) < Tuning.aiSpeculativeShotChance {
                intent.shoot = true
            }
        }
        return intent
    }

    /// A teammate with space around them, preferring those further upfield and not too far away.
    func openTeammate(for p: PlayerNode) -> PlayerNode? {
        let dir = attackDir[p.team]
        let opponents = players[1 - p.team].filter { !$0.isDown }
        var best: PlayerNode?
        var bestScore = -CGFloat.greatestFiniteMagnitude
        for t in players[p.team] where t !== p && !t.isDown && !t.isGoalie {
            let d = t.position - p.position
            let dist = d.length
            guard dist > 60, dist < 700 else { continue }
            let space = opponents.map { $0.position.distance(to: t.position) }.min() ?? 1000
            guard space > 70 else { continue }
            let forward = d.dx * dir
            let s = forward / 300 + space / 200 - dist / 600
            if s > bestScore {
                bestScore = s
                best = t
            }
        }
        return best
    }

    // MARK: Keeper

    func goalieIntent(for p: PlayerNode) -> PlayerIntent {
        var intent = PlayerIntent()
        let t = p.team
        let dir = attackDir[t]
        let own = ownGoalCenter(for: t)

        if ball.carrier === p {
            // Distribute to the best option; with nobody open, hoof it long downfield rather than
            // dribble out into the press.
            if p.thinkTimer <= 0 {
                p.thinkTimer = Tuning.keeperDistributionDelay
                intent.pass = true
                if let target = openTeammate(for: p) {
                    intent.aim = (target.position - p.position).normalized
                } else {
                    intent.aim = CGVector(dx: dir, dy: CGFloat.random(in: -0.5...0.5)).normalized
                }
            }
            return intent
        }

        let lineX = own.x + dir * 34

        // A shot is coming: read where it crosses the line and get there at full tilt.
        if ball.state == .flight, ball.velocity.dx * dir < -1 {
            let t = (lineX - ball.position.x) / ball.velocity.dx
            if t > 0, t < Tuning.keeperReadAhead {
                let reach = Tuning.goalHalfWidth + Tuning.playerRadius
                let yAt = clamp(ball.position.y + ball.velocity.dy * t, -reach, reach)
                let d = CGPoint(x: lineX, y: yAt) - p.position
                if d.length > 2 { intent.move = d.normalized }
                return intent
            }
        }

        // Come off the line for a loose ball nearby, but only when nobody else will get there first;
        // otherwise shadow the ball along the goal line.
        let ballDist = p.position.distance(to: ball.position)
        if ball.carrier == nil && ballDist < 150 && abs(ball.position.x - own.x) < 260 {
            let others = players[0] + players[1]
            let rivalDist = others
                .filter { $0 !== p && !$0.isDown }
                .map { $0.position.distance(to: ball.position) }
                .min() ?? .greatestFiniteMagnitude
            if ballDist < rivalDist + 20 {
                intent.move = (ball.position - p.position).normalized
                return intent
            }
        }

        // Shadow the ball: bias towards the line the carrier is on rather than sitting in the middle.
        let reach = Tuning.goalHalfWidth * 0.85
        let targetY = clamp(ball.position.y * 0.75, -reach, reach)
        let d = CGPoint(x: lineX, y: targetY) - p.position
        if d.length > 4 { intent.move = d.normalized * min(1, d.length / 40) }

        if let c = ball.carrier, c.team != t, p.tackleCooldown <= 0,
           c.position.distance(to: p.position) < Tuning.playerRadius * 2 + 24 {
            intent.move = (c.position - p.position).normalized
            intent.tackle = true
        }
        return intent
    }
}
