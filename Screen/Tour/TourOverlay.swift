import ScreenCore
import SwiftUI

/// The whole area except the lit control, as one shape with a hole.
struct SpotlightShape: Shape {
    var hole: CGRect
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}

/// Dims everything but the lit control. Touches inside the hole reach the real
/// control; touches anywhere else are swallowed so nobody wanders off.
struct TourOverlay: View {
    let step: TourStep
    let hole: CGRect
    let container: CGSize
    let onSkip: () -> Void
    let onAccept: (() -> Void)?

    var body: some View {
        let lit = hole.insetBy(dx: -8, dy: -8)
        let below = lit.maxY + 190 < container.height
        ZStack(alignment: .topLeading) {
            SpotlightShape(hole: lit, cornerRadius: 16)
                .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                .contentShape(SpotlightShape(hole: lit, cornerRadius: 16), eoFill: true)
                .onTapGesture {}
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.amber, lineWidth: 3)
                .frame(width: lit.width, height: lit.height)
                .position(x: lit.midX, y: lit.midY)
                .allowsHitTesting(false)
            TourBubble(step: step, onSkip: onSkip, onAccept: onAccept)
                .frame(width: min(container.width - 32, 380))
                .position(x: container.width / 2, y: below ? lit.maxY + 95 : max(95, lit.minY - 95))
        }
        .frame(width: container.width, height: container.height)
        .transition(.opacity)
    }
}

struct TourBubble: View {
    let step: TourStep
    let onSkip: () -> Void
    let onAccept: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TourCopy.title(step)).font(.headline).foregroundStyle(Theme.ink)
            Text(TourCopy.message(step)).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
            HStack {
                Text("Paso \(step.number) de \(TourStep.total)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let onAccept {
                    Button("Así está bien", action: onAccept).font(.caption.bold())
                }
                Button("Saltear", action: onSkip).font(.caption)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }
}
