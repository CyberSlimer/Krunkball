import SwiftUI

/// Pick a squad off the 32-team ladder. Used three times: your side in a quick match, the side you
/// play against, and the club you take over in a career.
struct TeamPickerView: View {
    let title: String
    let subtitle: String
    /// Team IDs that cannot be chosen (you cannot play yourself).
    var excluding: Set<String> = []
    let onPick: (TeamData) -> Void
    let onBack: () -> Void

    /// Written out rather than left to the synthesized memberwise initializer: this view is built
    /// from another file and it also carries private state, which is exactly where the memberwise
    /// initializer's access level gets interesting.
    init(title: String, subtitle: String, excluding: Set<String> = [],
         onPick: @escaping (TeamData) -> Void, onBack: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.excluding = excluding
        self.onPick = onPick
        self.onBack = onBack
    }

    /// Selection is by division number, not by index into the array: no clamping, and no key path
    /// into a tuple (Swift does not do those).
    @State private var selectedDivision = 1

    private var divisions: [Division] { League.divisions }

    private var division: Division {
        divisions.first { $0.id == selectedDivision } ?? divisions[0]
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 214, maximum: 280), spacing: 10)]
    }

    var body: some View {
        ZStack {
            DeckBackground()
            VStack(alignment: .leading, spacing: 12) {
                header
                divisionTabs
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(League.teams(in: division)) { team in
                            Button {
                                onPick(team)
                            } label: {
                                TeamCard(team: team, disabled: excluding.contains(team.id))
                            }
                            .buttonStyle(.plain)
                            .disabled(excluding.contains(team.id))
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .kerning(1.6)
                    .foregroundColor(Deck.text)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Deck.dim)
            }
            Spacer()
            Button("BACK", action: onBack)
                .buttonStyle(GhostButtonStyle())
        }
    }

    private var divisionTabs: some View {
        HStack(spacing: 8) {
            ForEach(divisions) { div in
                Button {
                    selectedDivision = div.id
                } label: {
                    VStack(spacing: 1) {
                        Text("DIV \(div.id)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .kerning(1)
                        Text(div.name)
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .kerning(0.6)
                            .opacity(0.7)
                    }
                    .foregroundColor(selectedDivision == div.id ? .white : Deck.dim)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(selectedDivision == div.id ? Deck.accent.opacity(0.8) : Color.white.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One squad on the ladder: kit, name, overall, and the shape of the squad's three stats.
struct TeamCard: View {
    let team: TeamData
    var disabled = false

    var body: some View {
        HStack(spacing: 10) {
            KitSwatch(kit: team.kit, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(team.name.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(0.6)
                    .foregroundColor(Deck.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                StatBar(label: "SPD", value: team.averageSpeed, tint: Deck.accent, width: 62)
                StatBar(label: "STR", value: team.averageStrength, tint: Deck.bad, width: 62)
                StatBar(label: "THR", value: team.averageThrowing, tint: Deck.gold, width: 62)
            }
            Spacer(minLength: 0)
            RatingBadge(value: team.rating)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Deck.plate)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(team.kit.primary.swiftUIColor.opacity(disabled ? 0.15 : 0.55), lineWidth: 1.5)
                )
        )
        .opacity(disabled ? 0.35 : 1)
    }
}
