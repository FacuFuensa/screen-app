import SwiftUI

/// A centered branded introduction for a screen.
struct HeroHeader: View {
    let symbol: String
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(LinearGradient(colors: [Theme.coral, Theme.amber], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            Text(title)
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A soft elevated container for related content.
struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: colorScheme == .light ? Color.black.opacity(0.055) : .clear, radius: 14, y: 5)
    }
}

/// A full-width coral call-to-action button style.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var color: Color = Theme.coral

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(color, in: Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// A full-width softly tinted secondary button style.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.coral)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.coral.opacity(0.12), in: Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// A selectable rounded pill for compact choices.
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(isSelected ? .white : Theme.ink)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(isSelected ? Theme.coral : Theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A deterministic initial avatar for a person's display name.
struct Avatar: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "?").uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.avatarColor(for: name), in: Circle())
    }
}

/// A compact icon-and-text status capsule.
struct StatusPill: View {
    let text: String
    let color: Color
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.13), in: Capsule())
    }
}

/// A friendly centered placeholder when a collection is empty.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(Theme.coral)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
