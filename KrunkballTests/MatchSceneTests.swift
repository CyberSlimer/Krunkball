import XCTest
import SpriteKit
@testable import Krunkball

/// Drives `MatchScene.update` by hand with a fixed 60 Hz step, so the whole match model can be
/// exercised deterministically without rendering a frame.
final class MatchSceneTests: XCTestCase {
    private var view: SKView!
    private var scene: MatchScene!
    private var now: TimeInterval = 0

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 956, height: 440))
        scene = MatchScene(teams: Roster.demoTeams(), size: view.bounds.size)
        view.presentScene(scene)     // triggers didMove(to:) which builds the arena and teams
        view.isPaused = true          // we step the simulation ourselves
        now = 0
        step()                        // first update seeds lastTime
    }

    override func tearDown() {
        view.presentScene(nil)
        view = nil
        scene = nil
        super.tearDown()
    }

    private func step(_ frames: Int = 1) {
        for _ in 0..<frames {
            now += 1.0 / 60.0
            scene.update(now)
        }
    }

    private func stepUntilPlaying() {
        var guardCount = 0
        while !scene.isPlaying && guardCount < 600 {
            step()
            guardCount += 1
        }
        XCTAssertTrue(scene.isPlaying, "match never reached the playing phase")
    }

    private var human: PlayerNode {
        guard let p = scene.controlledPlayer else {
            XCTFail("no controlled player")
            return scene.players[0][1]
        }
        return p
    }

    /// Put the ball on the human athlete's toes so the next frame's catch check hands it over.
    private func giveHumanTheBall() {
        let p = human
        scene.ball.position = p.position + CGVector(dx: Tuning.playerRadius + 2, dy: 0)
        scene.ball.velocity = .zero
        step()
        XCTAssertTrue(scene.ball.carrier === p, "human should have picked up the ball")
    }

    // MARK: Tests

    func testKickoffPlacesBallAtCentreAndFreezesPlay() {
        XCTAssertEqual(scene.ball.position, .zero)
        XCTAssertFalse(scene.isPlaying)
        XCTAssertEqual(scene.players[0].count, 10)
        XCTAssertEqual(scene.players[1].count, 10)
        XCTAssertNotNil(scene.controlledPlayer)
        XCTAssertFalse(scene.controlledPlayer!.isGoalie)
        stepUntilPlaying()
    }

    func testStickMovesTheControlledAthlete() {
        stepUntilPlaying()
        let p = human
        let start = p.position
        scene.controls.setKeyboardVector(CGVector(dx: 1, dy: 0))
        step(30)
        scene.controls.setKeyboardVector(.zero)
        XCTAssertGreaterThan(p.position.x - start.x, 60, "half a second of stick should cover real ground")
        XCTAssertEqual(p.facing, 0, accuracy: 0.01)
    }

    func testPickupThenShootReleasesTowardsAttackedGoal() {
        stepUntilPlaying()
        giveHumanTheBall()
        let p = human
        XCTAssertEqual(scene.controls.moveVector, .zero)
        scene.controls.triggerSecondary()      // SHOOT while carrying
        step()
        XCTAssertNil(scene.ball.carrier)
        XCTAssertEqual(scene.ball.state, .flight)
        XCTAssertTrue(scene.ball.lastThrower === p)
        let goalDir = scene.attackDir[scene.humanTeam]
        XCTAssertGreaterThan(scene.ball.velocity.dx * goalDir, 0, "shot must travel towards the attacked goal")
        XCTAssertGreaterThan(scene.ball.velocity.length, Tuning.shotSpeedBase - 1)
    }

    func testPickupThenPassGoesToATeammateInTheCone() {
        stepUntilPlaying()
        giveHumanTheBall()
        let p = human
        let dir = scene.attackDir[scene.humanTeam]
        scene.controls.setKeyboardVector(CGVector(dx: dir, dy: 0))
        scene.controls.triggerPrimary()        // PASS while carrying
        step()
        scene.controls.setKeyboardVector(.zero)
        XCTAssertNil(scene.ball.carrier)
        XCTAssertEqual(scene.ball.state, .flight)
        XCTAssertTrue(scene.ball.lastThrower === p)
        XCTAssertGreaterThan(scene.ball.velocity.dx * dir, 0)
        XCTAssertLessThan(scene.ball.velocity.length, Tuning.shotSpeedBase, "a pass is slower than a shot")
        // Let it fly: someone (not the thrower straight back) should end up with it or it lands loose.
        step(90)
        XCTAssertFalse(scene.ball.carrier === p && scene.ball.throwerImmunity > 0)
    }

    func testTackleOnOpposingCarrierEndsWithSomebodyDown() {
        stepUntilPlaying()
        // Hand the ball to an opponent and stand the human right in front of them, facing them.
        let victim = scene.players[1][5]
        let p = scene.selected!
        victim.position = CGPoint(x: 0, y: 0)
        victim.velocity = .zero
        p.position = CGPoint(x: -(Tuning.playerRadius * 2 + 24), y: 0)
        p.velocity = .zero
        p.facing = 0
        scene.ball.position = victim.position + CGVector(dx: Tuning.playerRadius + 1, dy: 0)
        step()
        XCTAssertTrue(scene.ball.carrier === victim)
        XCTAssertTrue(scene.controlledPlayer === p, "human should still steer the selected player")

        scene.controls.triggerSecondary()      // TACKLE without the ball
        step()
        XCTAssertEqual(p.state, .tackling)
        step(12)                               // lunge lands within 0.2 s
        let somebodyDown = victim.isDown || p.isDown
        XCTAssertTrue(somebodyDown, "a tackle contest always fells one side")
        if victim.isDown {
            XCTAssertFalse(scene.ball.carrier === victim, "a felled carrier drops the ball")
        }
    }

    func testSwitchCyclesSelectionWhenNotCarrying() {
        stepUntilPlaying()
        // Make sure the human side does not carry: park the ball on an opponent far away.
        let opp = scene.players[1][3]
        opp.position = CGPoint(x: 600, y: 300)
        scene.ball.position = opp.position + CGVector(dx: Tuning.playerRadius + 1, dy: 0)
        step()
        XCTAssertTrue(scene.ball.carrier === opp)
        let before = scene.selected
        scene.controls.triggerPrimary()        // SWITCH
        step()
        XCTAssertFalse(scene.selected === before)
        XCTAssertEqual(scene.selected?.team, scene.humanTeam)
    }

    func testGoalIsAwardedToAttackingTeamAndPlayResets() {
        stepUntilPlaying()
        let dir = scene.attackDir[scene.humanTeam]
        scene.ball.carrier = nil
        scene.ball.state = .loose
        scene.ball.position = CGPoint(x: dir * (Tuning.fieldLength / 2 - 5), y: 0)
        scene.ball.velocity = CGVector(dx: dir * 600, dy: 0)
        step(3)
        XCTAssertEqual(scene.score[scene.humanTeam], 1)
        XCTAssertEqual(scene.score[1 - scene.humanTeam], 0)
        XCTAssertFalse(scene.isPlaying)
        // Celebration then kickoff: the ball goes back to the centre spot.
        step(Int((Tuning.goalCelebration + 0.1) * 60))
        XCTAssertEqual(scene.ball.position, .zero)
    }

    func testBallReboundsOffSideWallButNotThroughGoalMouth() {
        stepUntilPlaying()
        scene.ball.carrier = nil
        scene.ball.state = .loose
        scene.ball.position = CGPoint(x: 0, y: Tuning.fieldWidth / 2 - 20)
        scene.ball.velocity = CGVector(dx: 0, dy: 900)
        step(3)
        XCTAssertLessThan(scene.ball.velocity.dy, 0, "ball should come back off the side wall")
        XCTAssertLessThanOrEqual(scene.ball.position.y, Tuning.fieldWidth / 2 - Tuning.ballRadius + 0.01)
    }

    func testFullMatchUnderAIRunsToFullTimeWithSaneScore() {
        // Nobody drives the human side here (no stick input), so this is close to autopilot for the
        // opposition and a worst case for the human team. It must still finish, and not be absurd.
        // Clock only runs while playing; every goal freezes it for celebration + kickoff, so budget generously.
        let frames = Int((Tuning.halfLength * 2 + 300) * 60)
        var reachedFullTime = false
        for _ in 0..<frames {
            step()
            if case .fullTime = scene.phase {
                reachedFullTime = true
                break
            }
        }
        XCTAssertTrue(reachedFullTime, "match must reach full time")
        XCTAssertEqual(scene.half, 2)
        let total = scene.score[0] + scene.score[1]
        XCTAssertLessThan(total, 30, "scoreline is out of control: \(scene.scoreline)")
        for team in scene.players {
            for p in team {
                XCTAssertLessThanOrEqual(abs(p.position.x), Tuning.fieldLength / 2)
                XCTAssertLessThanOrEqual(abs(p.position.y), Tuning.fieldWidth / 2)
            }
        }
    }

    // MARK: Pace, stamina and the idle handoff

    func testStickDeadZoneIgnoresATrembleButNotARealPush() {
        stepUntilPlaying()
        scene.controls.setKeyboardVector(CGVector(dx: 0.1, dy: 0))
        XCTAssertEqual(scene.controls.moveVector.length, 0, accuracy: 0.001,
                       "a nudge inside the dead zone must not drift the athlete")
        scene.controls.setKeyboardVector(CGVector(dx: 1, dy: 0))
        XCTAssertGreaterThan(scene.controls.moveVector.length, 0.9,
                             "a full push must still reach full speed")
        scene.controls.setKeyboardVector(.zero)
    }

    func testSprintingDrainsStaminaAndEasingOffPaysItBack() {
        // Driven directly rather than through a live match: who the scene hands the stick to
        // depends on where the ball is, and this is a statement about one athlete's lungs.
        let kit = League.team(id: "titans")?.kit ?? Kit.fallback
        let stats = PlayerStats(name: "Test Subject", speed: 60, strength: 60, throwing: 60)
        let p = PlayerNode(team: 0, squadIndex: 4, stats: stats, isGoalie: false, kit: kit)
        XCTAssertEqual(p.stamina, 1, accuracy: 0.001)
        let fresh = p.maxSpeed

        p.velocity = CGVector(dx: fresh, dy: 0)
        for _ in 0..<(60 * 8) { p.tick(dt: 1.0 / 60.0) }
        let drained = p.stamina
        XCTAssertLessThan(drained, 0.9, "eight seconds flat out has to cost something")
        XCTAssertLessThan(p.maxSpeed, fresh, "a tired athlete is a slower athlete")

        p.velocity = .zero
        for _ in 0..<(60 * 8) { p.tick(dt: 1.0 / 60.0) }
        XCTAssertGreaterThan(p.stamina, drained, "easing off has to pay stamina back")
        XCTAssertLessThanOrEqual(p.stamina, 1)
    }

    func testAFitterAthleteLastsLonger() {
        let kit = League.team(id: "titans")?.kit ?? Kit.fallback
        func drain(speed: Int) -> CGFloat {
            let p = PlayerNode(team: 0, squadIndex: 4,
                               stats: PlayerStats(name: "N", speed: speed, strength: 50, throwing: 50),
                               isGoalie: false, kit: kit)
            // Same effort fraction for both, so only the fitness term differs.
            p.velocity = CGVector(dx: p.maxSpeed, dy: 0)
            for _ in 0..<(60 * 6) { p.tick(dt: 1.0 / 60.0) }
            return p.stamina
        }
        XCTAssertGreaterThan(drain(speed: 90), drain(speed: 20),
                             "the speed stat doubles as fitness")
    }

    func testStaminaNeverLeavesItsRange() {
        stepUntilPlaying()
        scene.controls.setKeyboardVector(CGVector(dx: 1, dy: 0))
        step(60 * 60)
        scene.controls.setKeyboardVector(.zero)
        for team in scene.players {
            for p in team {
                XCTAssertGreaterThanOrEqual(p.stamina, 0)
                XCTAssertLessThanOrEqual(p.stamina, 1)
            }
        }
    }

    func testControlIsHandedToTheAIAfterASilentSpellAndTakenStraightBack() {
        stepUntilPlaying()
        XCTAssertFalse(scene.isIdleHandedOff)
        step(Int((Tuning.idleHandoffDelay + 0.2) * 60))
        XCTAssertTrue(scene.isIdleHandedOff, "an idle human side must not stand and watch")
        XCTAssertNil(scene.humanDriven)
        scene.controls.setKeyboardVector(CGVector(dx: 1, dy: 0))
        step()
        XCTAssertFalse(scene.isIdleHandedOff, "the first input takes the athlete straight back")
        XCTAssertNotNil(scene.humanDriven)
        scene.controls.setKeyboardVector(.zero)
    }

    func testDifficultyChangesTheAIsReactionTimeAndPress() {
        let casual = MatchScene(config: MatchConfig.quick(difficulty: .casual), size: view.bounds.size)
        let brutal = MatchScene(config: MatchConfig.quick(difficulty: .brutal), size: view.bounds.size)
        XCTAssertGreaterThan(casual.thinkInterval, brutal.thinkInterval)
        XCTAssertLessThan(casual.chaserCount(for: 1), brutal.chaserCount(for: 1))
        // Your own side always presses with the same number, whatever the setting.
        XCTAssertEqual(casual.chaserCount(for: 0), brutal.chaserCount(for: 0))
    }

    func testFullTimeReportsAResultToTheMenuExactlyOnce() {
        var results: [MatchResult] = []
        scene.onFinish = { results.append($0) }
        scene.clock = 0.05
        scene.half = 2
        stepUntilPlaying()
        step(60 * 3)
        XCTAssertEqual(results.count, 1, "the menu must be told once and only once")
        XCTAssertEqual(results.first?.score, scene.score)
        XCTAssertEqual(results.first?.humanTeam, scene.humanTeam)
    }
}
