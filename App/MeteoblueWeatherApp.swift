import SwiftUI

@main
struct MeteoblueWeatherApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView(model: model)
            }
            .task { await model.start() }
            .onOpenURL { model.handleRelayURL($0) }
        }
    }
}
