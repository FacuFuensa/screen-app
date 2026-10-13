import ScreenCore
import SwiftUI

struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [TourStep: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TourStep: Anchor<CGRect>], nextValue: () -> [TourStep: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks the control the tour lights up for `step`.
    func tourAnchor(_ step: TourStep) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [step: $0] }
    }

    /// Draws the tour overlay for any anchor inside this view.
    func tourHost() -> some View { modifier(TourHost()) }
}

struct TourHost: ViewModifier {
    @ObservedObject private var tour = TourController.shared

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(TourAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let step = tour.current, let anchor = anchors[step] {
                    TourOverlay(step: step, hole: proxy[anchor], container: proxy.size,
                                onSkip: { tour.skip() },
                                onAccept: step == .minutes ? { tour.complete(.minutes) } : nil)
                }
            }
        }
    }
}
