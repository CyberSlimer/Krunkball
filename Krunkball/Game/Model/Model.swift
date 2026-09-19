import CoreGraphics
import Foundation
import SpriteKit

/// A colour that survives a round trip through JSON, so squads and kits can be saved.
struct KitColor: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    var color: SKColor { SKColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1) }

    /// Mixed towards white (`amount` > 0) or black (`amount` < 0). Used for helmet highlights and trim.
    func shaded(_ amount: Double) -> KitColor {
        let t = min(max(amount, -1), 1)
        let target = t > 0 ? 1.0 : 0.0
        let k = abs(t)
        return KitColor(r + (target - r) * k, g + (target - g) * k, b + (target - b) * k)
    }
}

struct Kit: Codable, Equatable {
    var primary: KitColor      // jersey
    var secondary: KitColor    // shorts / sleeves
    var trim: KitColor         // helmet stripe, numbers

    static let fallback = Kit(primary: KitColor(0.4, 0.45, 0.5),
                              secondary: KitColor(0.15, 0.16, 0.18),
                              trim: KitColor(0.95, 0.95, 1))
}

/// What an athlete is best at. Derived from the stats rather than stored, so training a player
/// can move them from one role to another.
enum PlayerRole: String, Codable, CaseIterable {
    case blocker, runner, gunner, allRounder

    var displayName: String {
        switch self {
        case .blocker: return "BLOCKER"
        case .runner: return "RUNNER"
        case .gunner: return "GUNNER"
        case .allRounder: return "ALL-ROUND"
        }
    }

    var blurb: String {
        switch self {
        case .blocker: return "Wins the contact. Put them in front of your goal."
        case .runner: return "Carries the deck. Give them space and they are gone."
        case .gunner: return "An arm. Shoots from range and finds the long pass."
        case .allRounder: return "No holes, no fireworks."
        }
    }
}

/// The three stats the original tracked and upgraded. 0-100.
struct PlayerStats: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var speed: Int
    var strength: Int
    var throwing: Int

    var overall: Int { (speed + strength + throwing) / 3 }

    /// Whichever stat stands clearly above the others; no clear winner means all-rounder.
    var role: PlayerRole {
        let best = max(speed, max(strength, throwing))
        let worst = min(speed, min(strength, throwing))
        guard best - worst >= 8 else { return .allRounder }
        if best == strength { return .blocker }
        if best == speed { return .runner }
        return .gunner
    }

    /// How broad the athlete is drawn, 0 (lean) to 1 (slab). Strength builds, speed trims.
    var build: CGFloat {
        let raw = CGFloat(strength - speed) / 60 + 0.5
        return min(max(raw, 0), 1)
    }

    /// Asking price in credits. Steep at the top end so a superstar is a real decision.
    var value: Int {
        let o = Double(overall)
        return max(4, Int((o * o / 62).rounded()))
    }

    /// A single stat nudged by `delta`, clamped to the legal range. Used by difficulty scaling.
    func adjusted(by delta: Int) -> PlayerStats {
        var copy = self
        copy.speed = clamp(speed + delta, 10, 99)
        copy.strength = clamp(strength + delta, 10, 99)
        copy.throwing = clamp(throwing + delta, 10, 99)
        return copy
    }
}

struct TeamData: Codable, Equatable, Identifiable {
    var id: String              // stable slug, so a save can point at a league team
    var name: String
    var shortName: String
    var kit: Kit
    /// Ten players; index 0 is the goalkeeper.
    var players: [PlayerStats]

    var primary: SKColor { kit.primary.color }
    var secondary: SKColor { kit.secondary.color }
    var trim: SKColor { kit.trim.color }

    var rating: Int {
        guard !players.isEmpty else { return 0 }
        return players.map(\.overall).reduce(0, +) / players.count
    }

    var averageSpeed: Int { average(\.speed) }
    var averageStrength: Int { average(\.strength) }
    var averageThrowing: Int { average(\.throwing) }

    private func average(_ key: KeyPath<PlayerStats, Int>) -> Int {
        guard !players.isEmpty else { return 0 }
        return players.map { $0[keyPath: key] }.reduce(0, +) / players.count
    }

    /// Every stat on the squad nudged by `delta`. Difficulty applies this to the AI side.
    func adjusted(by delta: Int) -> TeamData {
        guard delta != 0 else { return self }
        var copy = self
        copy.players = players.map { $0.adjusted(by: delta) }
        return copy
    }

    /// The eleven... ten that actually take the deck, keeper first. Careers carry a bigger squad
    /// than the ten that play, so the match always builds from exactly ten.
    func matchDay() -> TeamData {
        guard players.count != 10 else { return self }
        var copy = self
        if players.count > 10 {
            copy.players = Array(players.prefix(10))
        } else {
            // Short squad: repeat the last outfield player rather than crash. Only reachable
            // if a save is hand-edited.
            var padded = players
            while padded.count < 10, let last = padded.last { padded.append(last) }
            copy.players = padded
        }
        return copy
    }
}

/// Nine outfield slots expressed in "attack space": x is towards the opponent goal, y is lateral.
struct Formation {
    let name: String
    let slots: [CGVector]

    static let balanced = Formation(name: "3-3-3", slots: [
        CGVector(dx: -330, dy: -240), CGVector(dx: -360, dy: 0), CGVector(dx: -330, dy: 240),
        CGVector(dx: -80, dy: -300),  CGVector(dx: -60, dy: 0),  CGVector(dx: -80, dy: 300),
        CGVector(dx: 200, dy: -200),  CGVector(dx: 240, dy: 0),  CGVector(dx: 200, dy: 200),
    ])

    static let attacking = Formation(name: "2-3-4", slots: [
        CGVector(dx: -340, dy: -150), CGVector(dx: -340, dy: 150),
        CGVector(dx: -90, dy: -300),  CGVector(dx: -60, dy: 0),  CGVector(dx: -90, dy: 300),
        CGVector(dx: 220, dy: -320),  CGVector(dx: 300, dy: -110), CGVector(dx: 300, dy: 110), CGVector(dx: 220, dy: 320),
    ])

    static let defensive = Formation(name: "4-3-2", slots: [
        CGVector(dx: -360, dy: -300), CGVector(dx: -390, dy: -100), CGVector(dx: -390, dy: 100), CGVector(dx: -360, dy: 300),
        CGVector(dx: -140, dy: -260), CGVector(dx: -120, dy: 0),   CGVector(dx: -140, dy: 260),
        CGVector(dx: 160, dy: -140),  CGVector(dx: 160, dy: 140),
    ])

    static let all: [Formation] = [balanced, attacking, defensive]

    static func index(named name: String) -> Int {
        all.firstIndex { $0.name == name } ?? 0
    }
}

/// SplitMix64: deterministic rosters, so a given seed always produces the same squad.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum Roster {
    static let firstNames = [
        "Axl", "Bruno", "Cass", "Dax", "Echo", "Faye", "Grit", "Hex", "Ivo", "Jett",
        "Kai", "Lux", "Moss", "Nyx", "Orin", "Pike", "Quill", "Rook", "Sable", "Tarn",
        "Ulric", "Vex", "Wren", "Xan", "Yara", "Zed", "Bex", "Cobalt", "Dree", "Ember",
        "Flint", "Gunnar", "Halo", "Indigo", "Juno", "Krait", "Lorn", "Mox", "Nine", "Onyx",
    ]
    static let lastNames = [
        "Voltage", "Kruger", "Steele", "Novak", "Blitz", "Harrow", "Ironside", "Kessler", "Marrow", "Oduya",
        "Prowse", "Razor", "Slade", "Tanaka", "Ulyanov", "Vance", "Wolfe", "Yamada", "Zorn", "Crank",
        "Achebe", "Bhandari", "Calder", "Dahl", "Ferro", "Grimaldi", "Hollis", "Ibarra", "Jansen", "Kowal",
        "Laszlo", "Mbeki", "Nakamura", "Ortiz", "Pashkov", "Quintero", "Rask", "Sandoval", "Thorne", "Vukovic",
    ]

    static func randomName(using rng: inout SeededGenerator) -> String {
        let first = firstNames.randomElement(using: &rng) ?? "Rook"
        let last = lastNames.randomElement(using: &rng) ?? "Steele"
        return "\(first) \(last)"
    }

    /// One athlete around `quality`, with a deliberate lean towards one stat so roles show up
    /// in a squad list instead of ten identical all-rounders.
    static func player(quality: Int, rng: inout SeededGenerator, keeper: Bool = false) -> PlayerStats {
        let lean = Int.random(in: 0...3, using: &rng)
        // Rolled one at a time rather than through a closure: a nested function here would have to
        // capture `rng`, which is inout.
        let speedRoll = Int.random(in: -12...12, using: &rng)
        let strengthRoll = Int.random(in: -12...12, using: &rng)
        let throwingRoll = Int.random(in: -12...12, using: &rng)
        var p = PlayerStats(name: randomName(using: &rng),
                            speed: clamp(quality + (lean == 0 ? 14 : -3) + speedRoll, 10, 99),
                            strength: clamp(quality + (lean == 1 ? 14 : -3) + strengthRoll, 10, 99),
                            throwing: clamp(quality + (lean == 2 ? 14 : -3) + throwingRoll, 10, 99))
        if keeper {
            p.throwing = clamp(p.throwing + 10, 10, 99)   // keepers need a good arm
            p.strength = clamp(p.strength + 6, 10, 99)
        }
        return p
    }

    static func generateTeam(id: String, name: String, shortName: String, kit: Kit,
                             quality: Int, seed: UInt64) -> TeamData {
        var rng = SeededGenerator(seed: seed)
        var players: [PlayerStats] = []
        for i in 0..<10 {
            players.append(player(quality: quality, rng: &rng, keeper: i == 0))
        }
        return TeamData(id: id, name: name, shortName: shortName, kit: kit, players: players)
    }

    /// The prototype's two squads, kept as the default quick-match pairing and as the fixed
    /// input to the balance benchmark. Seeds were picked so both sides profile the same.
    static func demoTeams() -> [TeamData] {
        [League.team(id: "titans") ?? fallbackTeam(id: "titans", name: "Neo Tokyo Titans", short: "TITANS", seed: 3322),
         League.team(id: "crushers") ?? fallbackTeam(id: "crushers", name: "Mars Colony Crushers", short: "CRUSHERS", seed: 3189)]
    }

    private static func fallbackTeam(id: String, name: String, short: String, seed: UInt64) -> TeamData {
        generateTeam(id: id, name: name, shortName: short, kit: .fallback, quality: 60, seed: seed)
    }
}
