import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @State private var confirmLeave = false

    var body: some View {
        TabView(selection: $router.tab) {
            GroupsView()
                .tabItem { Label("Límites", systemImage: "hourglass") }
                .tag(Router.Tab.groups)
            RequestsView()
                .tabItem { Label("Pedidos", systemImage: "hand.raised.fill") }
                .badge(router.incomingCount)
                .tag(Router.Tab.requests)
            FeedView()
                .tabItem { Label("Actividad", systemImage: "sparkles") }
                .tag(Router.Tab.feed)
        }
        .navigationTitle(app.partner.map { "Vos y \($0.displayName)" } ?? "Screen")
        .toolbar {
            Menu {
                Button("Pedir tiempo") { router.sheet = .ask(nil) }
                Button("Salir de la dupla", role: .destructive) { confirmLeave = true }
                Button("Cerrar sesión") {
                    Task {
                        guard !Demo.isOn else { return }
                        await app.backend.signOut()
                        await app.refresh()
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .confirmationDialog("¿Salir de la dupla con \(partnerName)? Tus límites siguen en este celular.", isPresented: $confirmLeave) {
            Button("Salir de la dupla", role: .destructive) {
                Task {
                    guard !Demo.isOn else { return }
                    try? await app.backend.leavePair()
                    await app.refresh()
                }
            }
        }
        .task { model.reload(); await model.loadRemote(partnerID: app.partner?.id) }
        .sheet(item: $router.sheet) { sheet in
            NavigationStack {
                switch sheet {
                case .ask(let groupID): AskTimeView(preselected: groupID)
                case .answer(let requestID): AnswerOtherView(requestID: requestID)
                }
            }
        }
        .sheet(item: $router.demoEditor) { group in NavigationStack { GroupEditorView(group: group) } }
    }

    private var partnerName: String { app.partner?.displayName ?? "tu dupla" }
}
