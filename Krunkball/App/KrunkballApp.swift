import SwiftUI

@main
struct KrunkballApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .persistentSystemOverlays(.hidden)
        }
    }
}

/// SwiftUI wrapper around the UIKit game controller. UIKit is used for the host so the
/// SKView can be first responder and receive hardware-keyboard presses (handy in the Simulator).
struct GameView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController { GameViewController() }
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}
