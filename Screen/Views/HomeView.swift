import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @State private var confirmLeave = false

    var body: some View {
        TabView(selection: $router.tab) {
            GroupsView()
                .tabItem { Label("Límites", systemImage: "hourglass") }.tag(Router.Tab.groups)
            Text("Pedidos")
                .tabItem { Label("Pedidos", systemImage: "hand.raised") }.tag(Router.Tab.requests)
            Text("Actividad")
                .tabItem { Label("Actividad", systemImage: "list.bullet") }.tag(Router.Tab.feed)
        }
        .navigationTitle(app.partner.map { "Con \($0.displayName)" } ?? "Screen")
        .toolbar {
            Menu {
                Button("Pedir tiempo") { router.sheet = .ask(nil) }
                Button("Desemparejar", role: .destructive) { confirmLeave = true }
                Button("Cerrar sesión") { Task { await app.backend.signOut(); await app.refresh() } }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .confirmationDialog("¿Desemparejarte? Tus límites siguen en este celular.", isPresented: $confirmLeave) {
            Button("Desemparejar", role: .destructive) {
                Task { try? await app.backend.leavePair(); await app.refresh() }
            }
        }
        .task { model.reload(); await model.loadRemote(partnerID: app.partner?.id) }
    }
}
