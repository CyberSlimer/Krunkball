import XCTest
import SpriteKit
@testable import Krunkball

/// AI vs AI over several full matches, headless. Prints the average scoreline and asserts it stays in
/// the band `CLAUDE.md` targets. The target is expressed as goals per minute of match clock so it
/// survives a change to `Tuning.halfLength`: 2-4 goals a side over 2 x 90 s is 0.67-1.33 goals a
/// minute in total. Run this after touching anything in `Tuning.swift` or the AI.
final class BalanceBenchmark: XCTestCase {
    private func playMatch() -> ([Int], [MatchScene.TeamStats]) {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 956, height: 440))
        let scene = MatchScene(teams: Roster.demoTeams(), size: view.bounds.size)
        scene.autopilot = true
        view.presentScene(scene)
        view.isPaused = true
        var now: TimeInterval = 0
        let frames = Int((Tuning.halfLength * 2 + 300) * 60)
        for _ in 0..<frames {
            now += 1.0 / 60.0
            scene.update(now)
            if case .fullTime = scene.phase { break }
        }
        view.presentScene(nil)
        return (scene.score, scene.stats)
    }

    func testAIvsAIScoringRate() {
        let matches = 10
        var home = 0, away = 0
        var lines: [String] = []
        var shots = [0, 0], saves = [0, 0], won = [0, 0], lost = [0, 0]
        for _ in 0..<matches {
            let (s, st) = playMatch()
            home += s[0]; away += s[1]
            lines.append("\(s[0])-\(s[1])")
            for t in 0..<2 {
                shots[t] += st[t].shots; saves[t] += st[t].saves
                won[t] += st[t].tacklesWon; lost[t] += st[t].tacklesLost
            }
        }
        print("BALANCE shots \(shots) keeper saves \(saves) tackles won \(won) lost \(lost) (totals over \(matches) matches)")
        let avgHome = Double(home) / Double(matches)
        let avgAway = Double(away) / Double(matches)
        let minutes = Tuning.halfLength * 2 / 60
        let perMinute = (avgHome + avgAway) / minutes
        print("BALANCE \(matches) matches: \(lines.joined(separator: "  "))  avg \(avgHome) - \(avgAway)  total \(avgHome + avgAway)  (\(perMinute) goals/min over \(minutes) min)")
        XCTAssertGreaterThan(perMinute, 0.5, "matches are too sterile")
        XCTAssertLessThan(perMinute, 1.6, "matches are too high-scoring")
    }
}
