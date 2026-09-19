import SwiftUI

/// Post-match card. `MatchScene.stats` was already being collected and never shown; this is it.
struct ResultView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            DeckBackground()
            if let result = app.lastResult {
                Plate(padding: 24) {
                    VStack(spacing: 14) {
                        Text(result.headline)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .kerning(3)
                            .foregroundColor(tint(result))

                        Text("\(result.humanGoals) — \(result.opponentGoals)")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(Deck.text)

                        Text("vs \(app.lastOpponentName.uppercased())")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .kerning(1.2)
                            .foregroundColor(Deck.dim)

                        Divider().background(Deck.line)

                        HStack(spacing: 26) {
                            stat("SHOTS", result.shots, result.humanTeam)
                            stat("SAVES", result.saves, result.humanTeam)
                            stat("TACKLES WON", result.tacklesWon, result.humanTeam)
                        }

                        if app.lastMatchWasCareer, let career = app.career {
                            Text(career.record.summary)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Deck.gold)
                        }

                        Button(app.lastMatchWasCareer ? "BACK TO THE CLUB" : "BACK TO MENU") {
                            app.dismissResult()
                        }
                        .buttonStyle(DeckButtonStyle(wide: true))
                        .padding(.top, 4)
                    }
                    .frame(width: 400)
                }
            }
        }
    }

    private func tint(_ result: MatchResult) -> Color {
        switch result.headline {
        case "WIN": return Deck.good
        case "LOSS": return Deck.bad
        default: return Deck.gold
        }
    }

    /// One row of the tale of the tape: yours against theirs.
    private func stat(_ label: String, _ values: [Int], _ humanTeam: Int) -> some View {
        let mine = values.indices.contains(humanTeam) ? values[humanTeam] : 0
        let theirs = values.indices.contains(1 - humanTeam) ? values[1 - humanTeam] : 0
        return VStack(spacing: 2) {
            Text("\(mine) — \(theirs)")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(Deck.text)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .kerning(0.8)
                .foregroundColor(Deck.dim)
        }
    }
}
