import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class StudioDisplayManager: ObservableObject {

    private static let nameHints = ["studio display", "cinema"]

    @Published private(set) var studioDisplay: CGDirectDisplayID?
    @Published private(set) var displayName: String = "Not Found"
    @Published var brightness: Float = 0.5

    private var reconfigCallback: CGDisplayReconfigurationCallBack?

    init() {
        rescan()
        registerReconfigurationCallback()
    }

    deinit {
        CGDisplayRemoveReconfigurationCallback(Self.reconfigurationTrampolineUnsafe, nil)
    }

    // MARK: - Detection

    func rescan() {
        let found = Self.matchingScreen()
        studioDisplay = found?.displayID
        displayName = found?.name ?? "Not Found"
        if let id = found?.displayID, let current = DisplayServicesBridge.getBrightness(for: id) {
            brightness = current
        }
    }

    /// `CGDisplayVendorNumber`/`IOServiceMatching("IODisplayConnect")` are unreliable on
    /// Apple Silicon (return static/non-unique values, and the IOKit service class is
    /// often unpopulated). `NSScreen.localizedName` is the stable, public source of truth.
    private static func matchingScreen() -> (displayID: CGDirectDisplayID, name: String)? {
        for screen in NSScreen.screens {
            let name = screen.localizedName
            guard nameHints.contains(where: { name.lowercased().contains($0) }) else { continue }
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            return (CGDirectDisplayID(number.uint32Value), name)
        }
        return nil
    }

    // MARK: - Brightness

    var canAdjustBrightness: Bool {
        guard let studioDisplay else { return false }
        return DisplayServicesBridge.canChangeBrightness(for: studioDisplay)
    }

    func setBrightness(_ value: Float) {
        guard let studioDisplay else { return }
        brightness = value
        DisplayServicesBridge.setBrightness(value, for: studioDisplay)
    }

    // MARK: - Sleep

    func sleepDisplay() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }

    // MARK: - Reconfiguration

    private func registerReconfigurationCallback() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(Self.reconfigurationTrampolineUnsafe, observer)
    }

    private nonisolated(unsafe) static let reconfigurationTrampolineUnsafe: CGDisplayReconfigurationCallBack = { _, _, userInfo in
        guard let userInfo else { return }
        let manager = Unmanaged<StudioDisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
        Task { @MainActor in
            manager.rescan()
        }
    }
}
