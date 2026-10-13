import SwiftUI

@main
struct ScreenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState()
    @StateObject private var router = Router.shared
    @StateObject private var groups = GroupsModel()
    @StateObject private var activity = ActivityModel()
    @StateObject private var tour = TourController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(router)
                .environmentObject(groups)
                .environmentObject(activity)
                .environmentObject(tour)
        }
    }
}
