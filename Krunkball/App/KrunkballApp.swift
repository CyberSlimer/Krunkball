import SwiftUI

@main
struct KrunkballApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .persistentSystemOverlays(.hidden)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}

/// The whole flow: menu -> pick a squad -> match -> result, or menu -> career -> club -> match.
struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            switch app.screen {
            case .menu:
                MenuView()

            case .quickPickHome:
                TeamPickerView(title: "PICK YOUR SQUAD",
                               subtitle: "32 teams, four divisions. Anyone can take anyone.",
                               onPick: { app.chooseQuickHome($0) },
                               onBack: { app.backToMenu() })

            case .quickPickAway:
                TeamPickerView(title: "PICK YOUR OPPONENT",
                               subtitle: "Difficulty still nudges their stats — check the menu setting.",
                               excluding: app.quickHomeExclusion,
                               onPick: { app.chooseQuickAway($0) },
                               onBack: { app.startQuickPick() })

            case .careerPickClub:
                TeamPickerView(title: "TAKE OVER A CLUB",
                               subtitle: "Start where you like. A weaker club means more credits go further.",
                               onPick: { app.startCareer(with: $0) },
                               onBack: { app.backToMenu() })

            case .club:
                ClubView()

            case .match:
                if let config = app.pendingConfig {
                    MatchHostView(config: config) { result in
                        app.finishMatch(result)
                    }
                    // Only the match runs edge to edge; the menus stay inside the safe area so
                    // nothing hides under the Dynamic Island in landscape.
                    .ignoresSafeArea()
                } else {
                    // Defensive: never strand the player on a blank screen.
                    Color.black.onAppear { app.backToMenu() }
                }

            case .result:
                ResultView()
            }
        }
        .background(Deck.background.ignoresSafeArea())
    }
}
