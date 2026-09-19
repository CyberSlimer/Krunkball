import Foundation

/// Four divisions of eight, mirroring the original's 32-team ladder. Every squad is generated
/// from a fixed seed, so the same team is the same team on every device and every launch.
struct Division: Identifiable {
    let id: Int
    let name: String
    let tag: String
    let teamIDs: [String]

    var displayName: String { "DIV \(id)  \(name)" }
}

enum League {
    /// One row of the ladder table. `quality` is the mean stat the squad is generated around.
    struct Entry {
        let id: String
        let name: String
        let shortName: String
        let quality: Int
        let seed: UInt64
        let kit: Kit
    }

    private static func kit(_ p: KitColor, _ s: KitColor, _ t: KitColor) -> Kit {
        Kit(primary: p, secondary: s, trim: t)
    }

    private static let white = KitColor(0.95, 0.96, 1)
    private static let ink = KitColor(0.09, 0.09, 0.12)
    private static let gold = KitColor(1, 0.82, 0.24)

    // MARK: The ladder

    static let entries: [Entry] = [
        // Division 1 — the Prime League
        Entry(id: "wraiths", name: "Titan Foundry Wraiths", shortName: "WRAITHS", quality: 76, seed: 9101,
              kit: kit(KitColor(0.35, 0.16, 0.55), ink, KitColor(0.88, 0.86, 0.78))),
        Entry(id: "solars", name: "Helios Prime Solars", shortName: "SOLARS", quality: 75, seed: 9102,
              kit: kit(KitColor(0.97, 0.52, 0.10), KitColor(0.10, 0.14, 0.32), white)),
        Entry(id: "voltage", name: "Kowloon Voltage", shortName: "VOLTAGE", quality: 75, seed: 9103,
              kit: kit(KitColor(0.92, 0.88, 0.16), ink, ink)),
        Entry(id: "ironworks", name: "Baikonur Ironworks", shortName: "IRONWORKS", quality: 74, seed: 9104,
              kit: kit(KitColor(0.58, 0.28, 0.16), KitColor(0.42, 0.45, 0.48), white)),
        Entry(id: "serpents", name: "Sao Paulo Serpents", shortName: "SERPENTS", quality: 74, seed: 9105,
              kit: kit(KitColor(0.10, 0.52, 0.28), ink, gold)),
        Entry(id: "glaciers", name: "Nordkapp Glaciers", shortName: "GLACIERS", quality: 73, seed: 9106,
              kit: kit(KitColor(0.62, 0.85, 0.95), KitColor(0.16, 0.30, 0.42), white)),
        Entry(id: "sandkings", name: "Cairo Sandkings", shortName: "SANDKINGS", quality: 73, seed: 9107,
              kit: kit(KitColor(0.86, 0.76, 0.48), KitColor(0.09, 0.38, 0.40), ink)),
        Entry(id: "redguard", name: "Vostok Red Guard", shortName: "RED GUARD", quality: 72, seed: 9108,
              kit: kit(KitColor(0.72, 0.10, 0.14), ink, gold)),

        // Division 2 — the Orbital Conference. The two demo squads live here.
        Entry(id: "titans", name: "Neo Tokyo Titans", shortName: "TITANS", quality: 60, seed: 3322,
              kit: kit(KitColor(0.15, 0.55, 1.0), white, white)),
        Entry(id: "crushers", name: "Mars Colony Crushers", shortName: "CRUSHERS", quality: 60, seed: 3189,
              kit: kit(KitColor(0.95, 0.25, 0.20), ink, white)),
        Entry(id: "tbirds", name: "Lagos Thunderbirds", shortName: "T-BIRDS", quality: 63, seed: 9203,
              kit: kit(KitColor(0.12, 0.62, 0.42), white, gold)),
        Entry(id: "cobras", name: "Chandigarh Cobras", shortName: "COBRAS", quality: 62, seed: 9204,
              kit: kit(KitColor(0.95, 0.66, 0.14), KitColor(0.20, 0.20, 0.22), ink)),
        Entry(id: "riptide", name: "Reykjavik Riptide", shortName: "RIPTIDE", quality: 61, seed: 9205,
              kit: kit(KitColor(0.18, 0.72, 0.74), KitColor(0.08, 0.16, 0.34), white)),
        Entry(id: "deadweight", name: "Detroit Deadweight", shortName: "DEADWEIGHT", quality: 60, seed: 9206,
              kit: kit(KitColor(0.38, 0.41, 0.45), KitColor(0.92, 0.44, 0.12), white)),
        Entry(id: "dustdevils", name: "Perth Dust Devils", shortName: "DEVILS", quality: 59, seed: 9207,
              kit: kit(KitColor(0.78, 0.55, 0.20), KitColor(0.35, 0.10, 0.14), white)),
        Entry(id: "canes", name: "Havana Hurricanes", shortName: "CANES", quality: 58, seed: 9208,
              kit: kit(KitColor(0.22, 0.78, 0.72), KitColor(0.95, 0.42, 0.38), ink)),

        // Division 3 — the Rust Belt
        Entry(id: "slagheap", name: "Sheffield Slagheap", shortName: "SLAGHEAP", quality: 53, seed: 9301,
              kit: kit(KitColor(0.30, 0.32, 0.34), KitColor(0.72, 0.36, 0.14), white)),
        Entry(id: "frostbite", name: "Novosibirsk Frostbite", shortName: "FROSTBITE", quality: 52, seed: 9302,
              kit: kit(KitColor(0.74, 0.80, 0.86), KitColor(0.14, 0.22, 0.34), ink)),
        Entry(id: "monsoon", name: "Manila Monsoon", shortName: "MONSOON", quality: 52, seed: 9303,
              kit: kit(KitColor(0.16, 0.34, 0.62), KitColor(0.60, 0.72, 0.80), white)),
        Entry(id: "tarantulas", name: "Tijuana Tarantulas", shortName: "TARANTULAS", quality: 51, seed: 9304,
              kit: kit(KitColor(0.20, 0.14, 0.18), KitColor(0.86, 0.26, 0.40), white)),
        Entry(id: "gantry", name: "Gdansk Gantry", shortName: "GANTRY", quality: 51, seed: 9305,
              kit: kit(KitColor(0.90, 0.76, 0.12), KitColor(0.26, 0.28, 0.32), ink)),
        Entry(id: "mako", name: "Mombasa Mako", shortName: "MAKO", quality: 50, seed: 9306,
              kit: kit(KitColor(0.22, 0.44, 0.52), white, gold)),
        Entry(id: "wolverines", name: "Winnipeg Wolverines", shortName: "WOLVERINES", quality: 50, seed: 9307,
              kit: kit(KitColor(0.52, 0.34, 0.16), KitColor(0.92, 0.88, 0.76), ink)),
        Entry(id: "vesuvians", name: "Naples Vesuvians", shortName: "VESUVIANS", quality: 49, seed: 9308,
              kit: kit(KitColor(0.14, 0.16, 0.20), KitColor(0.92, 0.32, 0.12), gold)),

        // Division 4 — the Scrap Division, where a new manager starts
        Entry(id: "bandsaws", name: "Ballarat Bandsaws", shortName: "BANDSAWS", quality: 45, seed: 9401,
              kit: kit(KitColor(0.66, 0.70, 0.74), KitColor(0.18, 0.20, 0.22), ink)),
        Entry(id: "claybank", name: "Cleveland Claybank", shortName: "CLAYBANK", quality: 45, seed: 9402,
              kit: kit(KitColor(0.70, 0.44, 0.32), KitColor(0.22, 0.26, 0.28), white)),
        Entry(id: "dockrats", name: "Dundee Dockrats", shortName: "DOCKRATS", quality: 44, seed: 9403,
              kit: kit(KitColor(0.24, 0.30, 0.28), KitColor(0.80, 0.78, 0.60), white)),
        Entry(id: "offcuts", name: "Odesa Offcuts", shortName: "OFFCUTS", quality: 44, seed: 9404,
              kit: kit(KitColor(0.18, 0.36, 0.56), KitColor(0.90, 0.84, 0.20), white)),
        Entry(id: "freight", name: "Fresno Freightliners", shortName: "FREIGHT", quality: 43, seed: 9405,
              kit: kit(KitColor(0.34, 0.18, 0.12), KitColor(0.84, 0.62, 0.20), white)),
        Entry(id: "kiln", name: "Kaohsiung Kiln", shortName: "KILN", quality: 43, seed: 9406,
              kit: kit(KitColor(0.84, 0.36, 0.18), KitColor(0.20, 0.18, 0.18), gold)),
        Entry(id: "tarpits", name: "Tromso Tarpits", shortName: "TARPITS", quality: 42, seed: 9407,
              kit: kit(KitColor(0.12, 0.12, 0.14), KitColor(0.46, 0.70, 0.64), white)),
        Entry(id: "bilgewater", name: "Belem Bilgewater", shortName: "BILGE", quality: 42, seed: 9408,
              kit: kit(KitColor(0.30, 0.46, 0.22), KitColor(0.58, 0.40, 0.18), white)),
    ]

    static let divisions: [Division] = [
        Division(id: 1, name: "PRIME LEAGUE", tag: "The money, the cameras, the lawsuits.",
                 teamIDs: ["wraiths", "solars", "voltage", "ironworks", "serpents", "glaciers", "sandkings", "redguard"]),
        Division(id: 2, name: "ORBITAL CONFERENCE", tag: "One good season from the big time.",
                 teamIDs: ["titans", "crushers", "tbirds", "cobras", "riptide", "deadweight", "dustdevils", "canes"]),
        Division(id: 3, name: "RUST BELT", tag: "Cheap seats, honest violence.",
                 teamIDs: ["slagheap", "frostbite", "monsoon", "tarantulas", "gantry", "mako", "wolverines", "vesuvians"]),
        Division(id: 4, name: "SCRAP DIVISION", tag: "Where a new manager starts.",
                 teamIDs: ["bandsaws", "claybank", "dockrats", "offcuts", "freight", "kiln", "tarpits", "bilgewater"]),
    ]

    // MARK: Lookup

    /// Built once: generating 32 squads is cheap but not free, and the menu asks for them constantly.
    static let allTeams: [TeamData] = entries.map {
        Roster.generateTeam(id: $0.id, name: $0.name, shortName: $0.shortName,
                            kit: $0.kit, quality: $0.quality, seed: $0.seed)
    }

    private static let byID: [String: TeamData] = Dictionary(
        uniqueKeysWithValues: allTeams.map { ($0.id, $0) }
    )

    static func team(id: String) -> TeamData? { byID[id] }

    static func teams(in division: Division) -> [TeamData] {
        division.teamIDs.compactMap { byID[$0] }
    }

    static func division(ofTeam id: String) -> Division? {
        divisions.first { $0.teamIDs.contains(id) }
    }

    static func entry(id: String) -> Entry? { entries.first { $0.id == id } }

    /// Everyone else in the same division — the pool a quick match or a fixture draws from.
    static func rivals(of id: String) -> [TeamData] {
        guard let div = division(ofTeam: id) else { return allTeams.filter { $0.id != id } }
        return teams(in: div).filter { $0.id != id }
    }

    // MARK: Transfer market

    /// Unsigned athletes, deterministic per `seed`. Careers keep their own market so signing a
    /// player actually removes him from it.
    static func freeAgents(seed: UInt64, count: Int = 12, quality: Int) -> [PlayerStats] {
        var rng = SeededGenerator(seed: seed)
        var pool: [PlayerStats] = []
        for i in 0..<count {
            // A couple of bargains, a couple of stars, the rest around the division's level.
            let swing = [-14, -9, -5, 0, 0, 4, 9, 16][i % 8]
            pool.append(Roster.player(quality: clamp(quality + swing, 20, 92), rng: &rng))
        }
        return pool.sorted { $0.overall > $1.overall }
    }
}
