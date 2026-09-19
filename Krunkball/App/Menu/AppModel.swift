import Foundation
import SwiftUI

/// Everything outside the match: which screen is up, the saved career, and the config for the
/// match about to be played. The SpriteKit scene knows nothing about any of it — it is handed a
/// `MatchConfig` and hands back a `MatchResult`.
final class AppModel: ObservableObject {
    enum Screen {
        case menu
        case quickPickHome      // choose the squad you will play as
        case quickPickAway      // choose who to play against
        case careerPickClub     // choose the club to manage
        case club               // squad, market, fixture
        case match
        case result
    }

    @Published private(set) var screen: Screen = .menu
    @Published var difficulty: Difficulty = .pro
    @Published private(set) var career: Career?
    @Published private(set) var pendingConfig: MatchConfig?
    @Published private(set) var lastResult: MatchResult?
    /// Set when the finished match belongs to a career, so the result screen goes back to the club.
    @Published private(set) var lastMatchWasCareer = false
    /// The opponent of the match just played, for the result screen's headline.
    @Published private(set) var lastOpponentName = ""

    private var quickHome: TeamData?

    /// The squad already picked for a quick match, so it cannot also be the opponent.
    var quickHomeExclusion: Set<String> {
        guard let id = quickHome?.id else { return [] }
        return [id]
    }

    var hasCareer: Bool { career != nil || CareerStore.hasSave }

    init() {
        career = CareerStore.load()
        if let saved = career { difficulty = saved.difficulty }
    }

    // MARK: Navigation

    func go(_ screen: Screen) {
        withAnimation(.easeInOut(duration: 0.2)) { self.screen = screen }
    }

    func backToMenu() { go(.menu) }

    // MARK: Quick match

    func startQuickPick() {
        quickHome = nil
        go(.quickPickHome)
    }

    func chooseQuickHome(_ team: TeamData) {
        quickHome = team
        go(.quickPickAway)
    }

    func chooseQuickAway(_ team: TeamData) {
        guard let home = quickHome else { return }
        lastOpponentName = team.name
        lastMatchWasCareer = false
        pendingConfig = MatchConfig.versus(human: home, opponent: team, difficulty: difficulty)
        go(.match)
    }

    /// Straight into the prototype's pairing, for when you just want to play.
    func startInstantMatch() {
        let demo = Roster.demoTeams()
        lastOpponentName = demo[1].name
        lastMatchWasCareer = false
        pendingConfig = MatchConfig.versus(human: demo[0], opponent: demo[1], difficulty: difficulty)
        go(.match)
    }

    // MARK: Career

    func openCareer() {
        if career == nil { career = CareerStore.load() }
        go(career == nil ? .careerPickClub : .club)
    }

    func startCareer(with club: TeamData) {
        var fresh = Career.new(clubID: club.id, difficulty: difficulty)
        fresh.difficulty = difficulty
        career = fresh
        CareerStore.save(fresh)
        go(.club)
    }

    func abandonCareer() {
        CareerStore.clear()
        career = nil
        go(.menu)
    }

    /// Mutate and persist in one step, so a signing can never be lost to a crash on the way out.
    func updateCareer(_ change: (inout Career) -> Void) {
        guard var c = career else { return }
        change(&c)
        career = c
        CareerStore.save(c)
    }

    func playNextFixture() {
        guard let c = career else { return }
        guard let opponent = c.nextOpponent else { return }
        lastOpponentName = opponent.name
        lastMatchWasCareer = true
        pendingConfig = MatchConfig.versus(human: c.club,
                                           opponent: opponent,
                                           difficulty: c.difficulty,
                                           formationIndex: c.formationIndex,
                                           isCareerMatch: true)
        go(.match)
    }

    // MARK: Results

    func finishMatch(_ result: MatchResult) {
        lastResult = result
        if lastMatchWasCareer {
            updateCareer { $0.bankResult(homeGoals: result.humanGoals, awayGoals: result.opponentGoals) }
        }
        // `pendingConfig` is deliberately left alone. Clearing it here publishes a change while
        // `screen` is still `.match`, and a re-render in that gap lands on the empty-config branch,
        // which bounces to the menu instead of showing the result. The next match overwrites it.
        go(.result)
    }

    func dismissResult() {
        go(lastMatchWasCareer ? .club : .menu)
    }
}
