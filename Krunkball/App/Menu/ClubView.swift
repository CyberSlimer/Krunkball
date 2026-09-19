import SwiftUI

/// The manager's desk: your squad, the ten that take the deck, the transfer market you recruit
/// from, and the button that starts the next fixture.
struct ClubView: View {
    @EnvironmentObject private var app: AppModel
    @State private var selectedID: UUID?
    @State private var note: String?

    private var career: Career? { app.career }

    var body: some View {
        ZStack {
            DeckBackground()
            if let career = career {
                HStack(alignment: .top, spacing: 14) {
                    clubColumn(career)
                    squadColumn(career)
                    marketColumn(career)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 12) {
                    Text("NO CAREER LOADED")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Deck.dim)
                    Button("BACK") { app.backToMenu() }
                        .buttonStyle(GhostButtonStyle())
                }
            }
        }
    }

    // MARK: Club

    private func clubColumn(_ career: Career) -> some View {
        let club = career.club
        return VStack(alignment: .leading, spacing: 10) {
            Plate {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        KitSwatch(kit: club.kit, size: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(club.name.uppercased())
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(Deck.text)
                                .lineLimit(2)
                            Text(League.division(ofTeam: club.id)?.displayName ?? "")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(Deck.dim)
                        }
                    }
                    HStack {
                        CreditsChip(credits: career.credits)
                        Spacer()
                        RatingBadge(value: career.squadRating, caption: "TEAM")
                    }
                    Text(career.record.summary)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Deck.dim)
                }
            }

            Plate {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: "NEXT FIXTURE")
                    if let opponent = career.nextOpponent {
                        HStack(spacing: 8) {
                            KitSwatch(kit: opponent.kit, size: 26)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(opponent.name.uppercased())
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(Deck.text)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("MATCH \(career.fixtureIndex + 1) OF \(career.fixtures.count)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(Deck.dim)
                            }
                            Spacer(minLength: 0)
                            RatingBadge(value: opponent.rating)
                        }
                        Button("PLAY MATCH") { app.playNextFixture() }
                            .buttonStyle(DeckButtonStyle(wide: true))
                    } else {
                        Text("SEASON COMPLETE — \(career.record.summary)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Deck.gold)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("START A NEW SEASON") {
                            app.updateCareer { $0.startNewSeason() }
                        }
                        .buttonStyle(DeckButtonStyle(tint: Deck.gold.opacity(0.85), wide: true))
                    }

                    Button {
                        app.updateCareer { $0.cycleFormation() }
                    } label: {
                        HStack {
                            Text("FORMATION")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(Deck.dim)
                            Spacer()
                            Text(career.formationName)
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(Deck.text)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let note = note {
                Text(note)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Deck.bad)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button("MENU") { app.backToMenu() }
                    .buttonStyle(GhostButtonStyle())
                Button("ABANDON") { app.abandonCareer() }
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .frame(width: 236)
    }

    // MARK: Squad

    private func squadColumn(_ career: Career) -> some View {
        Plate {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "SQUAD",
                             sub: "Tap two athletes to swap them. Slot GK plays in goal.")
                ScrollView {
                    VStack(spacing: 5) {
                        // Indexed by slot rather than by `enumerated()`: a key path into a tuple
                        // (`\.element.id`) is not something Swift supports.
                        ForEach(Array(career.lineup.indices), id: \.self) { index in
                            squadRow(career.lineup[index],
                                     slot: index == 0 ? "GK" : "\(index)",
                                     starting: true)
                        }
                        if !career.bench.isEmpty {
                            SectionTitle(text: "BENCH")
                                .padding(.top, 6)
                            ForEach(career.bench) { player in
                                squadRow(player, slot: "—", starting: false)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func squadRow(_ player: PlayerStats, slot: String, starting: Bool) -> some View {
        let isSelected = selectedID == player.id
        return HStack(spacing: 8) {
            Text(slot)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundColor(starting ? Deck.accent : Deck.dim)
                .frame(width: 22)
            PlayerIdentity(player: player)
            Spacer(minLength: 0)
            MiniStats(player: player)
            RatingBadge(value: player.overall)
            if !starting {
                Button {
                    app.updateCareer { $0.release(player) }
                    selectedID = nil
                    note = nil
                } label: {
                    Text("RELEASE")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundColor(Deck.bad)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Deck.bad.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Deck.accent.opacity(0.22) : Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isSelected ? Deck.accent : Color.clear, lineWidth: 1.5)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { tapSquadRow(player) }
    }

    private func tapSquadRow(_ player: PlayerStats) {
        note = nil
        guard let current = selectedID else {
            selectedID = player.id
            return
        }
        if current == player.id {
            selectedID = nil
            return
        }
        guard let other = app.career?.squad.first(where: { $0.id == current }) else {
            selectedID = player.id
            return
        }
        app.updateCareer { $0.swap(other, with: player) }
        selectedID = nil
    }

    // MARK: Market

    private func marketColumn(_ career: Career) -> some View {
        Plate {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "TRANSFER MARKET",
                             sub: "\(career.squad.count)/\(Tuning.maxSquadSize) under contract")
                ScrollView {
                    VStack(spacing: 5) {
                        if career.market.isEmpty {
                            Text("NOBODY LEFT ON THE LIST")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Deck.dim)
                                .padding(.vertical, 12)
                        }
                        ForEach(career.market) { player in
                            marketRow(player, career: career)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 292)
    }

    private func marketRow(_ player: PlayerStats, career: Career) -> some View {
        let affordable = career.canAfford(player)
        return HStack(spacing: 8) {
            PlayerIdentity(player: player)
            Spacer(minLength: 0)
            MiniStats(player: player)
            RatingBadge(value: player.overall)
            Button {
                if !career.canSign {
                    note = "Squad is full at \(Tuning.maxSquadSize). Release someone first."
                } else if career.credits < player.value {
                    note = "Not enough credits for \(player.name) (\(player.value) CR)."
                } else {
                    note = nil
                    app.updateCareer { $0.sign(player) }
                }
            } label: {
                VStack(spacing: -1) {
                    Text("\(player.value)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    Text("SIGN")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                }
                .foregroundColor(affordable ? .white : Deck.dim)
                .padding(.vertical, 5)
                .frame(width: 44)
                .background(RoundedRectangle(cornerRadius: 7)
                    .fill(affordable ? Deck.good.opacity(0.75) : Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.white.opacity(0.035)))
    }
}

/// Name over role tag — the same in every list so a squad and the market read alike.
struct PlayerIdentity: View {
    let player: PlayerStats

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(player.name.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(Deck.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(player.role.displayName)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .kerning(0.5)
                .foregroundColor(roleTint)
        }
        .frame(width: 96, alignment: .leading)
    }

    private var roleTint: Color {
        switch player.role {
        case .blocker: return Deck.bad
        case .runner: return Deck.accent
        case .gunner: return Deck.gold
        case .allRounder: return Deck.dim
        }
    }
}

/// The three stats as short bars, sized to sit inside a list row.
struct MiniStats: View {
    let player: PlayerStats

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            StatBar(label: "SPD", value: player.speed, tint: Deck.accent, width: 44)
            StatBar(label: "STR", value: player.strength, tint: Deck.bad, width: 44)
            StatBar(label: "THR", value: player.throwing, tint: Deck.gold, width: 44)
        }
    }
}
