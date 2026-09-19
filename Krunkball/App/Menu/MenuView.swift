import SwiftUI

/// Title screen. Also the place the controls are spelled out — the first build shipped with a
/// hidden stick and no instructions anywhere, which is exactly how you end up thinking the game
/// has no movement control.
struct MenuView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            DeckBackground()
            HStack(alignment: .top, spacing: 26) {
                leftColumn
                rightColumn
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 22)
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("KRUNKBALL")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .kerning(3)
                .foregroundColor(Deck.text)
            Text("FULL CONTACT  ·  TEN A SIDE  ·  NO RULES WORTH THE NAME")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .kerning(1.4)
                .foregroundColor(Deck.accent)
                .padding(.top, 2)

            Spacer(minLength: 18)

            VStack(spacing: 10) {
                Button("PLAY A MATCH") { app.startQuickPick() }
                    .buttonStyle(DeckButtonStyle(wide: true))

                Button(app.hasCareer ? "CONTINUE CAREER" : "START A CAREER") { app.openCareer() }
                    .buttonStyle(DeckButtonStyle(tint: Deck.gold.opacity(0.85), wide: true))

                Button("EXHIBITION: TITANS vs CRUSHERS") { app.startInstantMatch() }
                    .buttonStyle(GhostButtonStyle())
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 14)

            difficultyPicker
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var difficultyPicker: some View {
        Plate {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "DIFFICULTY")
                HStack(spacing: 8) {
                    ForEach(Difficulty.allCases) { d in
                        Button {
                            app.difficulty = d
                        } label: {
                            Text(d.displayName)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .kerning(1)
                                .foregroundColor(app.difficulty == d ? .white : Deck.dim)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(app.difficulty == d ? Deck.accent.opacity(0.8) : Color.white.opacity(0.04))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(app.difficulty.blurb)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Deck.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rightColumn: some View {
        Plate {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "HOW TO PLAY", sub: "Two halves of two minutes. Get it in their goal.")

                controlRow(glyph: "◎", title: "MOVE",
                           detail: "Drag anywhere on the LEFT of the screen. The stick follows your thumb. Keyboard: W A S D.")
                controlRow(glyph: "●", title: "PASS / SWITCH",
                           detail: "Blue button. Passes to whoever you are aiming at; without the ball it switches athlete. Key: H.")
                controlRow(glyph: "●", title: "SHOOT / TACKLE",
                           detail: "Red button. Shoots at their goal; without the ball it is a lunging tackle. Key: G.")
                controlRow(glyph: "▤", title: "FORMATION",
                           detail: "Top-right button cycles 3-3-3, 2-3-4 and 4-3-2. Key: J.")

                Divider().background(Deck.line)

                Text("STAMINA drains while you sprint and comes back when you ease off, so pick your runs. The bar under your athlete is the one to watch.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Deck.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 330)
    }

    private func controlRow(glyph: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(glyph)
                .font(.system(size: 15))
                .foregroundColor(Deck.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(1)
                    .foregroundColor(Deck.text)
                Text(detail)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(Deck.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
