import SwiftUI

@main
struct StudioDisplayControlApp: App {
    @StateObject private var manager = StudioDisplayManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: manager)
        } label: {
            Image(systemName: manager.studioDisplay != nil ? "display" : "display.trianglebadge.exclamationmark")
        }
        .menuBarExtraStyle(.window)
    }
}
