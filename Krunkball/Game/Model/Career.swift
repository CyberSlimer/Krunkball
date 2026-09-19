import Foundation

/// A saved manager career: the club you took over, the squad you own, the credits you have left
/// to spend, and how the season is going. Small enough to live in `UserDefaults` as JSON;
/// SwiftData can take over when there is more than one save to keep.
struct Career: Codable, Equatable {
    var clubID: String
    var difficulty: Difficulty
    var credits: Int
    /// The whole squad you own. Index 0 is the keeper, 1...9 take the deck, 10+ are the bench.
    var squad: [PlayerStats]
    /// Athletes currently on the transfer list, already priced.
    var market: [PlayerStats]
    var formationName: String
    var fixtureIndex: Int
    var record: Record

    struct Record: Codable, Equatable {
        var played = 0
        var won = 0
        var drawn = 0
        var lost = 0
        var goalsFor = 0
        var goalsAgainst = 0

        var points: Int { won * 3 + drawn }
        var goalDifference: Int { goalsFor - goalsAgainst }
        var summary: String { "\(won)W \(drawn)D \(lost)L   \(goalsFor):\(goalsAgainst)   \(points) pts" }
    }

    // MARK: Derived

    var club: TeamData {
        var team = League.team(id: clubID) ?? Roster.demoTeams()[0]
        team.players = squad
        return team
    }

    /// The ten that take the deck, keeper first.
    var lineup: [PlayerStats] { Array(squad.prefix(10)) }
    var bench: [PlayerStats] { squad.count > 10 ? Array(squad.dropFirst(10)) : [] }

    var formationIndex: Int { Formation.index(named: formationName) }

    var fixtures: [TeamData] {
        let rivals = League.rivals(of: clubID)
        return rivals + rivals      // home and away
    }

    var nextOpponent: TeamData? {
        let list = fixtures
        guard !list.isEmpty else { return nil }
        return fixtureIndex < list.count ? list[fixtureIndex] : nil
    }

    var seasonComplete: Bool { fixtureIndex >= fixtures.count }

    var squadRating: Int {
        let ten = lineup
        guard !ten.isEmpty else { return 0 }
        return ten.map(\.overall).reduce(0, +) / ten.count
    }

    // MARK: Setup

    static func new(clubID: String, difficulty: Difficulty) -> Career {
        let club = League.team(id: clubID) ?? Roster.demoTeams()[0]
        let quality = League.entry(id: clubID)?.quality ?? 55
        // Seed the market off the club's own ladder seed: String.hashValue is randomised per
        // process, so it would hand the same club a different market on every launch.
        let seed = (League.entry(id: clubID)?.seed ?? 4242) &* 31 &+ 17
        return Career(clubID: clubID,
                      difficulty: difficulty,
                      credits: Tuning.startingCredits,
                      squad: club.players,
                      market: League.freeAgents(seed: seed, quality: quality),
                      formationName: Formation.balanced.name,
                      fixtureIndex: 0,
                      record: Record())
    }

    // MARK: Squad management

    var canSign: Bool { squad.count < Tuning.maxSquadSize }

    func canAfford(_ player: PlayerStats) -> Bool { credits >= player.value && canSign }

    /// Buy an athlete off the market onto the bench. No-op if they are gone, unaffordable,
    /// or the squad is already full.
    mutating func sign(_ player: PlayerStats) {
        guard let idx = market.firstIndex(where: { $0.id == player.id }) else { return }
        guard canAfford(player) else { return }
        credits -= player.value
        market.remove(at: idx)
        squad.append(player)
    }

    /// Sell an athlete back for part of their value. The ten that play cannot drop below ten,
    /// so releasing a starter promotes the first bench player in their place.
    mutating func release(_ player: PlayerStats) {
        guard squad.count > 10 else { return }
        guard let idx = squad.firstIndex(where: { $0.id == player.id }) else { return }
        guard idx != 0 else { return }          // never release the only keeper
        credits += Int((Double(player.value) * Tuning.releaseRefund).rounded())
        squad.remove(at: idx)
        market.append(player)
        market.sort { $0.overall > $1.overall }
    }

    /// Swap an athlete between the starting ten and the bench. Slot 0 (the keeper) is swapped
    /// like any other slot, so a better arm can go in goal.
    mutating func swap(_ a: PlayerStats, with b: PlayerStats) {
        guard let i = squad.firstIndex(where: { $0.id == a.id }),
              let j = squad.firstIndex(where: { $0.id == b.id }), i != j else { return }
        squad.swapAt(i, j)
    }


    mutating func cycleFormation() {
        let next = (formationIndex + 1) % Formation.all.count
        formationName = Formation.all[next].name
    }

    // MARK: Results

    /// Book the result and pay the gate: a win earns more, and goals always earn something.
    /// Named `bankResult` rather than `record` so it cannot be confused with the `record` property.
    mutating func bankResult(homeGoals: Int, awayGoals: Int) {
        record.played += 1
        record.goalsFor += homeGoals
        record.goalsAgainst += awayGoals
        var purse = 6 + homeGoals * 2
        if homeGoals > awayGoals {
            record.won += 1
            purse += 18
        } else if homeGoals == awayGoals {
            record.drawn += 1
            purse += 9
        } else {
            record.lost += 1
        }
        credits += purse
        fixtureIndex += 1
    }

    mutating func startNewSeason() {
        fixtureIndex = 0
        record = Record()
    }
}

/// Where the save lives. One slot for now; `key` is versioned so a model change can be ignored
/// rather than crash on an old save.
enum CareerStore {
    private static let key = "krunkball.career.v1"

    static func load() -> Career? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Career.self, from: data)
    }

    static func save(_ career: Career) {
        guard let data = try? JSONEncoder().encode(career) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static var hasSave: Bool { UserDefaults.standard.data(forKey: key) != nil }
}
