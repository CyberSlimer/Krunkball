import XCTest
import SpriteKit
@testable import Krunkball

/// AI vs AI over several full matches, headless. Prints the average scoreline and asserts it stays in
/// the band `CLAUDE.md` targets (roughly 2–4 goals a side per match). Run this after touching anything
/// in `Tuning.swift` or the AI.
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
        print("BALANCE \(matches) matches: \(lines.joined(separator: "  "))  avg \(avgHome) - \(avgAway)  total \(avgHome + avgAway)")
        XCTAssertGreaterThan(avgHome + avgAway, 2.0, "matches are too sterile")
        XCTAssertLessThan(avgHome + avgAway, 9.0, "matches are too high-scoring")
    }
}
