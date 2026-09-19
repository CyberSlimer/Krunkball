import Foundation

/// Everything the match needs to know before it kicks off. Built by the menu (or by
/// `MatchConfig.quick` for a one-off) and handed to `MatchScene`.
struct MatchConfig {
    var teams: [TeamData]           // exactly two, index 0 kicks off attacking +x
    var humanTeam: Int              // 0 or 1; -1 for AI vs AI
    var difficulty: Difficulty
    var halfLength: TimeInterval
    var formationIndex: Int         // the human side's starting shape
    /// True when a result should be written back into a career save.
    var isCareerMatch: Bool

    /// Two league squads, the human on the left. Difficulty nudges the opposition's stats, which
    /// is what actually makes "brutal" brutal rather than just faster reactions.
    static func versus(human: TeamData, opponent: TeamData, difficulty: Difficulty,
                       formationIndex: Int = 0, isCareerMatch: Bool = false,
                       halfLength: TimeInterval = Tuning.halfLength) -> MatchConfig {
        MatchConfig(teams: [human.matchDay(),
                            opponent.matchDay().adjusted(by: difficulty.opponentStatBonus)],
                    humanTeam: 0,
                    difficulty: difficulty,
                    halfLength: halfLength,
                    formationIndex: formationIndex,
                    isCareerMatch: isCareerMatch)
    }

    /// The prototype's pairing, for a straight "I just want to play" tap.
    static func quick(difficulty: Difficulty = .pro) -> MatchConfig {
        let demo = Roster.demoTeams()
        return versus(human: demo[0], opponent: demo[1], difficulty: difficulty)
    }

    var homeName: String { teams.first?.name ?? "HOME" }
    var awayName: String { teams.count > 1 ? teams[1].name : "AWAY" }
}

/// What came back out of a match, so the menu can show it and a career can bank it.
struct MatchResult: Equatable {
    var score: [Int]
    var humanTeam: Int
    var shots: [Int]
    var saves: [Int]
    var tacklesWon: [Int]

    var humanGoals: Int { humanTeam >= 0 && humanTeam < score.count ? score[humanTeam] : score[0] }
    var opponentGoals: Int { humanTeam == 0 ? score[1] : score[0] }

    var headline: String {
        if humanGoals > opponentGoals { return "WIN" }
        if humanGoals < opponentGoals { return "LOSS" }
        return "DRAW"
    }
}
