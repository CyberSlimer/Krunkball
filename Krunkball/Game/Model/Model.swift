import SpriteKit

/// The three stats the original tracked and upgraded. 0-100.
struct PlayerStats {
    var name: String
    var speed: Int
    var strength: Int
    var throwing: Int

    var overall: Int { (speed + strength + throwing) / 3 }
}

struct TeamData {
    var name: String
    var shortName: String
    var primary: SKColor
    var secondary: SKColor
    /// Ten players; index 0 is the goalkeeper.
    var players: [PlayerStats]
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
        "Ulric", "Vex", "Wren", "Xan", "Yara", "Zed",
    ]
    static let lastNames = [
        "Voltage", "Kruger", "Steele", "Novak", "Blitz", "Harrow", "Ironside", "Kessler", "Marrow", "Oduya",
        "Prowse", "Razor", "Slade", "Tanaka", "Ulyanov", "Vance", "Wolfe", "Yamada", "Zorn", "Crank",
    ]

    static func generateTeam(name: String, shortName: String, primary: SKColor, secondary: SKColor,
                             quality: Int, seed: UInt64) -> TeamData {
        var rng = SeededGenerator(seed: seed)
        var players: [PlayerStats] = []
        for i in 0..<10 {
            let first = firstNames.randomElement(using: &rng) ?? "Rook"
            let last = lastNames.randomElement(using: &rng) ?? "Steele"
            func stat() -> Int { clamp(quality + Int.random(in: -18...18, using: &rng), 10, 99) }
            var p = PlayerStats(name: "\(first) \(last)", speed: stat(), strength: stat(), throwing: stat())
            if i == 0 { p.throwing = clamp(p.throwing + 10, 10, 99) }   // keepers need a good arm
            players.append(p)
        }
        return TeamData(name: name, shortName: shortName, primary: primary, secondary: secondary, players: players)
    }

    /// Seeds were picked so both squads profile the same (avg speed / strength / back line / forwards
    /// all ~60): the prototype's balance benchmark depends on it.
    static func demoTeams() -> [TeamData] {
        [
            generateTeam(name: "Neo Tokyo Titans", shortName: "TITANS",
                         primary: SKColor(red: 0.15, green: 0.55, blue: 1.0, alpha: 1),
                         secondary: SKColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1),
                         quality: 60, seed: 3322),
            generateTeam(name: "Mars Colony Crushers", shortName: "CRUSHERS",
                         primary: SKColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1),
                         secondary: SKColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1),
                         quality: 60, seed: 3189),
        ]
    }
}
