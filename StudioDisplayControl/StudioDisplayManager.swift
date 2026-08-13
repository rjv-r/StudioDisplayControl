import AppKit
import Combine
import CoreGraphics
import Foundation
import IOKit

@MainActor
final class StudioDisplayManager: ObservableObject {

    /// Apple's registered vendor ID for its own displays.
    private static let appleVendorID: UInt32 = 0x05AC
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
        let found = Self.activeDisplays().first { id in
            Self.isStudioDisplay(id)
        }
        studioDisplay = found
        displayName = found.flatMap { Self.name(for: $0) } ?? "Not Found"
        if let found, let current = DisplayServicesBridge.getBrightness(for: found) {
            brightness = current
        }
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        return displays
    }

    private static func isStudioDisplay(_ id: CGDirectDisplayID) -> Bool {
        guard CGDisplayVendorNumber(id) == appleVendorID else { return false }
        guard let name = name(for: id)?.lowercased() else { return false }
        return nameHints.contains { name.contains($0) }
    }

    private static func name(for id: CGDirectDisplayID) -> String? {
        let vendorID = CGDisplayVendorNumber(id)
        let productID = CGDisplayModelNumber(id)

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { service = IOIteratorNext(iterator) }

            guard let info = IODisplayCreateInfoDictionary(
                service,
                IOOptionBits(kIODisplayOnlyPreferredName)
            )?.takeRetainedValue() as? [String: Any] else { continue }

            let entryVendorID = info[kDisplayVendorID] as? UInt32
            let entryProductID = info[kDisplayProductID] as? UInt32
            guard entryVendorID == vendorID, entryProductID == productID else { continue }

            guard let names = info[kDisplayProductName] as? [String: String] else { continue }
            return names.values.first
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
