import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @EnvironmentObject var activity: ActivityModel
    @EnvironmentObject var tour: TourController
    @State private var confirmLeave = false

    var body: some View {
        TabView(selection: $router.tab) {
            NavigationStack {
                YoView().navigationTitle("Yo").toolbar { menu }
            }
            .tabItem { Label("Yo", systemImage: "hourglass") }
            .tag(Router.Tab.me)

            NavigationStack {
                PartnerView().navigationTitle(partnerTitle).toolbar { menu }
            }
            .tabItem { Label(partnerTitle, systemImage: "person.fill") }
            .badge(activity.incoming(from: app.partner?.id).count)
            .tag(Router.Tab.partner)
        }
        .confirmationDialog("¿Salir de la dupla con \(partnerTitle)? Tus límites siguen en este celular.",
                            isPresented: $confirmLeave) {
            Button("Salir de la dupla", role: .destructive) {
                Task {
                    guard !Demo.isOn else { return }
                    try? await app.backend.leavePair()
                    await app.refresh()
                }
            }
        }
        .task { await refreshAll() }
        .onReceive(NotificationCenter.default.publisher(for: .screenDataChanged)) { _ in
            Task { await refreshAll() }
        }
        .onChange(of: router.tab) { _, _ in Task { await refreshAll() } }
        .task(id: waiting) {
            // While I wait for an answer, check every 10 s so the result shows up
            // even if the push is late or the app was opened from the home screen.
            guard waiting, !Demo.isOn else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if Task.isCancelled { break }
                await SyncService.shared.run()
                await refreshAll()
            }
        }
        .sheet(item: $router.sheet) { sheet in
            NavigationStack {
                switch sheet {
                case .ask(let groupID): AskTimeView(preselected: groupID)
                case .answer(let requestID): AnswerOtherView(requestID: requestID)
                }
            }
        }
        .sheet(item: $router.demoEditor) { request in
            NavigationStack { GroupEditorView(group: request.original, startingDraft: request.draft) }
        }
        .onChange(of: app.isPaired) { _, paired in if paired { tour.pairingCompleted() } }
        .sheet(isPresented: $tour.showFinal) { TourFinalView() }
    }

    private var partnerTitle: String { app.partner?.displayName ?? "Tu dupla" }
    private var waiting: Bool { activity.hasOwnPending(me: app.me?.id) || !model.pendingByGroup.isEmpty }

    private var menu: some View {
        Menu {
            Button("Ver el recorrido de nuevo") { router.tab = .me; tour.restart() }
            if app.isPaired {
                Button("Salir de la dupla", role: .destructive) { confirmLeave = true }
            }
            Button("Cerrar sesión") {
                Task {
                    guard !Demo.isOn else { return }
                    await app.backend.signOut()
                    await app.refresh()
                }
            }
        } label: { Image(systemName: "ellipsis.circle") }
    }

    func refreshAll() async {
        model.reload()
        await activity.load()
        await model.loadRemote(partnerID: app.partner?.id)
    }
}
