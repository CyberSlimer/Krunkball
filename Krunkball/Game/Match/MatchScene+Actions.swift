import SpriteKit

// Ball handling and contact resolution: tackles, drops, catches, passes, shots, goals.
extension MatchScene {

    // MARK: Tackles

    /// Strength contest with a random swing. Winner stays up; the loser eats the deck.
    /// Tackling a carrier jars the ball loose. A carrier that is mid-tackle or recovering is easier to fell.
    func resolveTackle(tackler: PlayerNode, victim: PlayerNode) {
        tackler.tackleHitPending = false
        let attack = CGFloat(tackler.stats.strength) * 1.15 + CGFloat.random(in: 0...45)
        var defense = CGFloat(victim.stats.strength) + CGFloat.random(in: 0...45)
        if victim.state != .active { defense -= 20 }

        if attack >= defense {
            let dir = tackler.velocity.normalized
            victim.knockDown(for: Tuning.knockdownDuration)
            victim.velocity = dir * 160
            if ball.carrier === victim {
                let scatter = CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: -60...60))
                dropBall(from: victim, impulse: dir * 150 + scatter)
            }
            tackler.velocity = tackler.velocity * 0.4
        } else {
            tackler.knockDown(for: Tuning.failedTackleDuration)
            tackler.velocity = -tackler.velocity.normalized * 120
        }
    }

    // MARK: Possession

    func dropBall(from p: PlayerNode, impulse: CGVector) {
        guard ball.carrier === p else { return }
        ball.carrier = nil
        ball.state = .loose
        ball.velocity = impulse
        ball.lastThrower = nil
        ball.setAirborne(false)
        p.pickupDelay = Tuning.dropPickupDelay
        if p.team == humanTeam { selectNearestToBall() }
    }

    func takeBall(_ p: PlayerNode) {
        ball.carrier = p
        ball.state = .held
        ball.velocity = .zero
        ball.lastThrower = nil
        ball.airTime = 0
        ball.throwerImmunity = 0
        ball.setAirborne(false)

        if p.team == humanTeam {
            selected = p
        } else if lastPossessingTeam == humanTeam || lastPossessingTeam == nil {
            // The human side just lost it: hand the stick to whoever is best placed to win it back.
            selectNearestToBall()
        }
        lastPossessingTeam = p.team
    }

    // MARK: Passing and shooting

    /// Pass towards the best teammate in the aimed cone; with nobody there, sling it in the aimed direction.
    func pass(from p: PlayerNode, aim: CGVector) {
        let dir = aim.length > 0.3 ? aim.normalized : CGVector(angle: p.facing)
        let speed = Tuning.passSpeedBase + CGFloat(p.stats.throwing) * Tuning.passSpeedPerStat
        var throwDir = dir
        if let target = bestPassTarget(for: p, direction: dir) {
            let dist = p.position.distance(to: target.position)
            let lead = target.position + target.velocity * (dist / speed)
            throwDir = (lead - p.position).normalized
        }
        release(from: p, direction: throwDir, speed: speed, airTime: Tuning.passAirTime)
    }

    func bestPassTarget(for p: PlayerNode, direction: CGVector) -> PlayerNode? {
        var best: PlayerNode?
        var bestScore = -CGFloat.greatestFiniteMagnitude
        for t in players[p.team] where t !== p && !t.isDown {
            let d = t.position - p.position
            let dist = d.length
            guard dist > 1 else { continue }
            let cosA = d.dot(direction) / dist
            guard cosA > 0.25 else { continue }
            let s = cosA * 2.0 - dist / 900 - (t.isGoalie ? 0.8 : 0)
            if s > bestScore {
                bestScore = s
                best = t
            }
        }
        return best
    }

    /// Shots always travel towards the goal the shooter attacks; the stick nudges the aim across the mouth.
    /// Throwing stat tightens the spread and adds pace.
    func shoot(from p: PlayerNode, aim: CGVector) {
        let goal = goalCenter(for: p.team)
        let maxAim = Tuning.goalHalfWidth * 0.85
        let aimY = clamp(aim.dy * maxAim, -maxAim, maxAim)
        var dir = (CGPoint(x: goal.x, y: aimY) - p.position).normalized
        let spread = (1 - CGFloat(p.stats.throwing) / 100) * 0.16
        dir = CGVector(angle: dir.angle + CGFloat.random(in: -spread...spread))
        let speed = Tuning.shotSpeedBase + CGFloat(p.stats.throwing) * Tuning.shotSpeedPerStat
        release(from: p, direction: dir, speed: speed, airTime: Tuning.shotAirTime)
    }

    func release(from p: PlayerNode, direction: CGVector, speed: CGFloat, airTime: TimeInterval) {
        guard ball.carrier === p else { return }
        ball.carrier = nil
        ball.state = .flight
        ball.velocity = direction * speed
        ball.airTime = airTime
        ball.throwerImmunity = Tuning.throwerImmunity
        ball.lastThrower = p
        ball.setAirborne(true)
        ball.position = p.position + direction * (Tuning.playerRadius + Tuning.ballRadius + 2)
        p.facing = direction.angle
    }

    // MARK: Ball integration

    func updateBall(_ dt: TimeInterval) {
        let fdt = CGFloat(dt)
        switch ball.state {
        case .held:
            guard let c = ball.carrier else {
                ball.state = .loose
                return
            }
            ball.position = c.position + CGVector(angle: c.facing) * (Tuning.playerRadius + Tuning.ballRadius - 3)
            ball.velocity = c.velocity

        case .flight:
            ball.airTime -= dt
            ball.throwerImmunity -= dt
            ball.position += ball.velocity * fdt
            bounceBall()
            if ball.airTime <= 0 {
                ball.state = .loose
                ball.setAirborne(false)
                if lastPossessingTeam == humanTeam { selectNearestToBall() }
            }
            if checkGoal() { return }
            checkCatch(excludeThrower: ball.throwerImmunity > 0)

        case .loose:
            ball.velocity = ball.velocity * pow(Tuning.ballDragPerSecond, fdt)
            ball.position += ball.velocity * fdt
            bounceBall()
            if checkGoal() { return }
            checkCatch(excludeThrower: false)
        }
    }

    /// Rebound off the side walls and end walls; the goal mouths are the only openings.
    private func bounceBall() {
        let r = Tuning.ballRadius
        let hl = Tuning.fieldLength / 2
        let hw = Tuning.fieldWidth / 2
        let e = Tuning.wallRestitution

        if ball.position.y > hw - r {
            ball.position.y = hw - r
            ball.velocity.dy = -abs(ball.velocity.dy) * e
        }
        if ball.position.y < -hw + r {
            ball.position.y = -hw + r
            ball.velocity.dy = abs(ball.velocity.dy) * e
        }

        let inMouth = abs(ball.position.y) < Tuning.goalHalfWidth - r
        if inMouth {
            let back = hl + Tuning.goalDepth - r
            if ball.position.x > back {
                ball.position.x = back
                ball.velocity.dx = 0
            }
            if ball.position.x < -back {
                ball.position.x = -back
                ball.velocity.dx = 0
            }
        } else {
            if ball.position.x > hl - r {
                ball.position.x = hl - r
                ball.velocity.dx = -abs(ball.velocity.dx) * e
            }
            if ball.position.x < -hl + r {
                ball.position.x = -hl + r
                ball.velocity.dx = abs(ball.velocity.dx) * e
            }
        }
    }

    private func checkGoal() -> Bool {
        let hl = Tuning.fieldLength / 2
        guard abs(ball.position.y) < Tuning.goalHalfWidth else { return false }
        if ball.position.x > hl + Tuning.ballRadius {
            scoreGoal(for: attackDir[0] > 0 ? 0 : 1)
            return true
        }
        if ball.position.x < -hl - Tuning.ballRadius {
            scoreGoal(for: attackDir[0] < 0 ? 0 : 1)
            return true
        }
        return false
    }

    /// Anyone upright who touches the ball takes it, nearest first. A flying ball can be intercepted by
    /// anybody but the thrower, and a keeper simply catches it (no knock-down-the-keeper exploit).
    private func checkCatch(excludeThrower: Bool) {
        var best: PlayerNode?
        var bestDist = CGFloat.greatestFiniteMagnitude
        let reach = Tuning.playerRadius + Tuning.ballRadius + Tuning.catchSlack
        for team in players {
            for p in team {
                guard !p.isDown, p.pickupDelay <= 0 else { continue }
                if excludeThrower && p === ball.lastThrower { continue }
                let d = p.position.distance(to: ball.position)
                if d < reach && d < bestDist {
                    bestDist = d
                    best = p
                }
            }
        }
        if let p = best { takeBall(p) }
    }
}
