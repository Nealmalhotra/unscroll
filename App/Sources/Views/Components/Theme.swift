import SwiftUI

enum Theme {
    static let accent = Color(red: 0.16, green: 0.55, blue: 0.43)
    static let warm = Color(red: 0.98, green: 0.62, blue: 0.29)
    static let danger = Color(red: 0.89, green: 0.30, blue: 0.31)
    static let beast = Color(red: 0.93, green: 0.36, blue: 0.18)
    static let corner: CGFloat = 20
    static let padding: CGFloat = 16

    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.10, green: 0.36, blue: 0.30), Color(red: 0.16, green: 0.55, blue: 0.43)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(Theme.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

struct SectionTitle: View {
    let title: String
    var symbol: String?
    var trailing: AnyView?

    var body: some View {
        HStack {
            if let symbol { Image(systemName: symbol).foregroundStyle(Theme.accent) }
            Text(title).font(.headline)
            Spacer()
            trailing
        }
    }
}

struct RingProgress: View {
    let fraction: Double
    var lineWidth: CGFloat = 12
    var color: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: fraction)
        }
    }
}

struct StatPill: View {
    let symbol: String
    let value: String
    let label: String
    var color: Color = Theme.accent

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension View {
    func primaryButton(_ color: Color = Theme.accent) -> some View { buttonStyle(PrimaryButtonStyle(color: color)) }
}
