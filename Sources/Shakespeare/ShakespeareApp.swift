import SwiftUI

@main
struct ShakespeareApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "keyboard")
                Text(model.todayCount.formatted())
            }
        }
        .menuBarExtraStyle(.window)

        Window("Share card", id: "card") {
            CardStudioView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}
