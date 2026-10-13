import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel

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
        .task { await foreground() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await foreground() } } }
    }

    private func foreground() async {
        await app.refresh()
        await SyncService.shared.run()
        model.reload()
        let store = SharedStore()
        if let ask = store.load(PendingAsk.self, key: SharedKey.pendingAsk) {
            store.remove(SharedKey.pendingAsk)
            if Date().timeIntervalSince(ask.createdAt) < 600, app.phase == .ready { router.sheet = .ask(ask.groupID) }
        }
    }
}
