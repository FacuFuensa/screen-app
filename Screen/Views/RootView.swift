import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            switch app.phase {
            case .loading: ProgressView()
            case .signedOut: AuthView()
            case .needsScreenTime: ScreenTimeGateView()
            case .unpaired: PairingView()
            case .ready: HomeView()
            }
        }
        .task { await app.refresh() }
    }
}
