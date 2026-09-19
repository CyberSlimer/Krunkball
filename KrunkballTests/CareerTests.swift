import XCTest
@testable import Krunkball

/// The manager layer: the ladder is well formed, and signing / releasing moves credits and
/// squad places the way the club screen assumes it does.
final class CareerTests: XCTestCase {

    func testLadderIsWellFormed() {
        XCTAssertEqual(League.divisions.count, 4)
        XCTAssertEqual(League.allTeams.count, 32)
        for division in League.divisions {
            XCTAssertEqual(division.teamIDs.count, 8, "division \(division.id) is not eight teams")
            for id in division.teamIDs {
                XCTAssertNotNil(League.team(id: id), "\(id) is listed in a division but never generated")
            }
        }
        let ids = Set(League.allTeams.map(\.id))
        XCTAssertEqual(ids.count, 32, "team ids must be unique — the save points at them")
        for team in League.allTeams {
            XCTAssertEqual(team.players.count, 10, "\(team.id) must field ten")
        }
    }

    func testDivisionsDescendInStrength() {
        func meanRating(_ division: Division) -> Double {
            let teams = League.teams(in: division)
            return Double(teams.map(\.rating).reduce(0, +)) / Double(teams.count)
        }
        let means = League.divisions.map(meanRating)
        for i in 1..<means.count {
            XCTAssertLessThan(means[i], means[i - 1], "division \(i + 1) should be weaker than \(i)")
        }
    }

    func testDemoTeamsStillComeFromTheLadderAndProfileTheSame() {
        let demo = Roster.demoTeams()
        XCTAssertEqual(demo.count, 2)
        XCTAssertEqual(demo[0].id, "titans")
        XCTAssertEqual(demo[1].id, "crushers")
        // The balance benchmark leans on these two being evenly matched, stat by stat: a 4-point
        // throwing gap once showed up as a 2:1 scoreline. The seeds were searched to match within a
        // point per stat, so any drift here means the generator changed and a reseed is due.
        for (label, key) in [("speed", \TeamData.averageSpeed), ("strength", \TeamData.averageStrength),
                             ("throwing", \TeamData.averageThrowing), ("rating", \TeamData.rating)] {
            XCTAssertLessThanOrEqual(abs(demo[0][keyPath: key] - demo[1][keyPath: key]), 1,
                                     "demo squads drifted apart on \(label): \(demo[0][keyPath: key]) vs \(demo[1][keyPath: key])")
        }
        XCTAssertLessThanOrEqual(abs(demo[0].players[0].overall - demo[1].players[0].overall), 2, "keepers drifted apart")
    }

    func testNewCareerStartsWithTheClubSquadAndAMarket() {
        let career = Career.new(clubID: "dockrats", difficulty: .pro)
        XCTAssertEqual(career.squad.count, 10)
        XCTAssertEqual(career.lineup.count, 10)
        XCTAssertTrue(career.bench.isEmpty)
        XCTAssertEqual(career.credits, Tuning.startingCredits)
        XCTAssertFalse(career.market.isEmpty)
        XCTAssertEqual(career.fixtures.count, 14, "seven rivals, home and away")
        XCTAssertNotNil(career.nextOpponent)
    }

    func testMarketIsDeterministicForAClub() {
        let a = Career.new(clubID: "kiln", difficulty: .pro)
        let b = Career.new(clubID: "kiln", difficulty: .brutal)
        XCTAssertEqual(a.market.map(\.name), b.market.map(\.name),
                       "a club's market must not change between launches")
    }

    func testSigningSpendsCreditsAndFillsTheBench() {
        var career = Career.new(clubID: "bandsaws", difficulty: .pro)
        // Pick someone we can actually afford.
        guard let target = career.market.first(where: { $0.value <= career.credits }) else {
            return XCTFail("nobody on the market is affordable at \(career.credits) credits")
        }
        let before = career.credits
        career.sign(target)
        XCTAssertEqual(career.credits, before - target.value)
        XCTAssertEqual(career.squad.count, 11)
        XCTAssertEqual(career.bench.map(\.id), [target.id], "a signing goes to the bench, not the ten")
        XCTAssertFalse(career.market.contains { $0.id == target.id })
    }

    func testSigningIsRefusedWithoutTheCredits() {
        var career = Career.new(clubID: "bandsaws", difficulty: .pro)
        career.credits = 0
        guard let target = career.market.first else { return XCTFail("empty market") }
        career.sign(target)
        XCTAssertEqual(career.squad.count, 10)
        XCTAssertEqual(career.credits, 0)
    }

    func testSquadCannotGrowPastTheCap() {
        var career = Career.new(clubID: "bandsaws", difficulty: .pro)
        career.credits = 100_000
        for player in career.market { career.sign(player) }
        XCTAssertEqual(career.squad.count, Tuning.maxSquadSize)
    }

    func testSwapPromotesABenchPlayerIntoTheTen() {
        var career = Career.new(clubID: "offcuts", difficulty: .pro)
        career.credits = 100_000
        guard let signing = career.market.first else { return XCTFail("empty market") }
        career.sign(signing)
        let starter = career.lineup[5]
        career.swap(signing, with: starter)
        XCTAssertTrue(career.lineup.contains { $0.id == signing.id })
        XCTAssertTrue(career.bench.contains { $0.id == starter.id })
    }

    func testReleaseRefundsAndNeverDropsBelowTen() {
        var career = Career.new(clubID: "offcuts", difficulty: .pro)
        career.credits = 100_000
        guard let signing = career.market.first else { return XCTFail("empty market") }
        career.sign(signing)
        let before = career.credits
        career.release(signing)
        XCTAssertEqual(career.squad.count, 10)
        XCTAssertGreaterThan(career.credits, before)

        // With only ten under contract nobody can leave.
        let starter = career.lineup[4]
        career.release(starter)
        XCTAssertEqual(career.squad.count, 10)
    }

    func testResultsBookPointsGoalsAndGateMoney() {
        var career = Career.new(clubID: "tarpits", difficulty: .pro)
        let start = career.credits
        career.bankResult(homeGoals: 3, awayGoals: 1)
        career.bankResult(homeGoals: 0, awayGoals: 2)
        career.bankResult(homeGoals: 1, awayGoals: 1)
        XCTAssertEqual(career.record.played, 3)
        XCTAssertEqual(career.record.won, 1)
        XCTAssertEqual(career.record.lost, 1)
        XCTAssertEqual(career.record.drawn, 1)
        XCTAssertEqual(career.record.points, 4)
        XCTAssertEqual(career.record.goalsFor, 4)
        XCTAssertEqual(career.record.goalsAgainst, 4)
        XCTAssertEqual(career.fixtureIndex, 3)
        XCTAssertGreaterThan(career.credits, start, "a season has to pay for itself")
    }

    func testCareerSurvivesAJSONRoundTrip() throws {
        var career = Career.new(clubID: "monsoon", difficulty: .brutal)
        career.credits = 100_000
        if let signing = career.market.first { career.sign(signing) }
        career.bankResult(homeGoals: 2, awayGoals: 2)
        let data = try JSONEncoder().encode(career)
        let restored = try JSONDecoder().decode(Career.self, from: data)
        XCTAssertEqual(restored, career)
    }

    func testRolesAndValuesFollowTheStats() {
        let brick = PlayerStats(name: "Slab", speed: 40, strength: 88, throwing: 44)
        let sprinter = PlayerStats(name: "Wire", speed: 90, strength: 41, throwing: 50)
        let arm = PlayerStats(name: "Cannon", speed: 50, strength: 52, throwing: 89)
        let even = PlayerStats(name: "Plain", speed: 60, strength: 62, throwing: 58)
        XCTAssertEqual(brick.role, .blocker)
        XCTAssertEqual(sprinter.role, .runner)
        XCTAssertEqual(arm.role, .gunner)
        XCTAssertEqual(even.role, .allRounder)
        XCTAssertGreaterThan(brick.build, sprinter.build, "strength builds, speed trims")
        XCTAssertGreaterThan(arm.value, even.value, "a better athlete costs more")
    }

    func testDifficultyOnlyAdjustsTheOpposition() {
        let demo = Roster.demoTeams()
        let brutal = MatchConfig.versus(human: demo[0], opponent: demo[1], difficulty: .brutal)
        let casual = MatchConfig.versus(human: demo[0], opponent: demo[1], difficulty: .casual)
        XCTAssertEqual(brutal.teams[0].rating, demo[0].rating, "your own squad is never rescaled")
        XCTAssertEqual(casual.teams[0].rating, demo[0].rating)
        XCTAssertGreaterThan(brutal.teams[1].rating, casual.teams[1].rating)
        XCTAssertGreaterThan(Difficulty.casual.thinkMultiplier, Difficulty.brutal.thinkMultiplier,
                             "casual has to react more slowly")
        XCTAssertGreaterThan(Difficulty.brutal.chasers, Difficulty.casual.chasers)
    }

    func testAnOversizedSquadStillFieldsExactlyTen() {
        var career = Career.new(clubID: "gantry", difficulty: .pro)
        career.credits = 100_000
        for player in career.market { career.sign(player) }
        XCTAssertGreaterThan(career.squad.count, 10)
        XCTAssertEqual(career.club.matchDay().players.count, 10)
    }
}
