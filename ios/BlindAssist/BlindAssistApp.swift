import SwiftUI

@main
struct BlindAssistApp: App {
    @StateObject private var model = NavigationModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            DashboardView(model: model)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .background { model.suspendExperience() }
                    if phase == .active { model.resumeExperienceIfNeeded() }
                }
        }
    }
}
