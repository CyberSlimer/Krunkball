import SwiftUI

/// Shared look for the out-of-match screens: the same dark deck, the same plates and chips, so the
/// menus read as part of the same machine as the arena.
enum Deck {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.085)
    static let plate = Color(red: 0.11, green: 0.13, blue: 0.16)
    static let plateHigh = Color(red: 0.16, green: 0.19, blue: 0.23)
    static let line = Color.white.opacity(0.10)
    static let text = Color.white
    static let dim = Color.white.opacity(0.55)
    static let accent = Color(red: 0.25, green: 0.65, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.24)
    static let good = Color(red: 0.36, green: 0.85, blue: 0.5)
    static let bad = Color(red: 0.95, green: 0.38, blue: 0.34)
}

extension KitColor {
    var swiftUIColor: Color { Color(red: r, green: g, blue: b) }
}

/// Background for every menu screen.
struct DeckBackground: View {
    var body: some View {
        ZStack {
            Deck.background
            // Faint deck stripes, echoing the arena turf.
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<14, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(i % 2 == 0 ? 0.012 : 0))
                            .frame(width: geo.size.width / 14)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct Plate<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Deck.plate)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Deck.line, lineWidth: 1)
                    )
            )
    }
}

/// The chunky primary action button.
struct DeckButtonStyle: ButtonStyle {
    var tint: Color = Deck.accent
    var wide = false

    /// Spelled out rather than `wide ? .infinity : nil`: an implicit member on the wrapped type of
    /// an optional is exactly the kind of expression the type checker argues about.
    private var widthLimit: CGFloat? {
        guard wide else { return nil }
        return CGFloat.infinity
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .kerning(1.2)
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
            .frame(maxWidth: widthLimit)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.55 : 0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A quieter button for back / secondary actions.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .kerning(1)
            .foregroundColor(Deck.dim)
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Deck.line, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.02)))
            )
    }
}

/// Section heading in the arena's stencil voice.
struct SectionTitle: View {
    let text: String
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .kerning(1.6)
                .foregroundColor(Deck.dim)
            if let sub = sub {
                Text(sub)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Deck.dim.opacity(0.7))
            }
        }
    }
}

/// A team's colours as a little jersey chip.
struct KitSwatch: View {
    let kit: Kit
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(kit.primary.swiftUIColor)
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(kit.secondary.swiftUIColor)
                .frame(width: size * 0.3)
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(kit.trim.swiftUIColor.opacity(0.9), lineWidth: 2)
        }
        .frame(width: size, height: size)
    }
}

/// A 0-100 stat as a labelled bar.
struct StatBar: View {
    let label: String
    let value: Int
    var tint: Color = Deck.accent
    var width: CGFloat = 78

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(Deck.dim)
                .frame(width: 22, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule().fill(tint)
                    .frame(width: max(3, width * CGFloat(value) / 100))
            }
            .frame(width: width, height: 5)
            Text("\(value)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Deck.text.opacity(0.8))
                .frame(width: 20, alignment: .trailing)
        }
    }
}

/// The big number on a team or player card.
struct RatingBadge: View {
    let value: Int
    var caption: String = "OVR"

    private var tint: Color {
        if value >= 72 { return Deck.good }
        if value >= 55 { return Deck.gold }
        return Deck.dim
    }

    var body: some View {
        VStack(spacing: -2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
            Text(caption)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .kerning(1)
                .foregroundColor(Deck.dim)
        }
        .frame(width: 40)
    }
}

/// Credits, shown the same way everywhere it appears.
struct CreditsChip: View {
    let credits: Int

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Deck.gold).frame(width: 8, height: 8)
            Text("\(credits) CR")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundColor(Deck.gold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Deck.gold.opacity(0.12)))
    }
}
