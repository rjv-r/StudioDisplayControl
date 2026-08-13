import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: StudioDisplayManager
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: manager.studioDisplay != nil ? "display" : "display.trianglebadge.exclamationmark")
                    .foregroundStyle(manager.studioDisplay != nil ? .primary : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.displayName)
                        .font(.headline)
                    Text(manager.studioDisplay != nil ? "Connected" : "Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Label("Brightness", systemImage: "sun.max")
                    .font(.subheadline)
                Slider(
                    value: Binding(
                        get: { manager.brightness },
                        set: { newValue in
                            manager.brightness = newValue
                            debounceTask?.cancel()
                            debounceTask = Task {
                                try? await Task.sleep(for: .milliseconds(50))
                                guard !Task.isCancelled else { return }
                                manager.setBrightness(newValue)
                            }
                        }
                    ),
                    in: 0...1
                )
                .disabled(!manager.canAdjustBrightness)
            }

            Divider()

            Button {
                manager.sleepDisplay()
            } label: {
                Label("Sleep Display", systemImage: "moon.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(manager.studioDisplay == nil)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 240)
    }
}
