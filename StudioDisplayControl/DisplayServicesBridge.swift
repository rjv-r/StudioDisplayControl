import CoreGraphics
import Foundation

/// Weakly-linked bindings to Apple's private DisplayServices.framework.
/// Apple ships no public header for these; symbols are resolved at launch
/// and calls degrade gracefully (return non-zero / false) if unavailable.
enum DisplayServicesBridge {

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanChangeBrightnessFn = @convention(c) (CGDirectDisplayID) -> Bool

    private nonisolated(unsafe) static let handle: UnsafeMutableRawPointer? = {
        dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        )
    }()

    private nonisolated(unsafe) static let getBrightnessFn: GetBrightnessFn? = {
        guard let handle, let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightnessFn.self)
    }()

    private nonisolated(unsafe) static let setBrightnessFn: SetBrightnessFn? = {
        guard let handle, let sym = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(sym, to: SetBrightnessFn.self)
    }()

    private nonisolated(unsafe) static let canChangeBrightnessFn: CanChangeBrightnessFn? = {
        guard let handle, let sym = dlsym(handle, "DisplayServicesCanChangeBrightness") else { return nil }
        return unsafeBitCast(sym, to: CanChangeBrightnessFn.self)
    }()

    static var isAvailable: Bool {
        getBrightnessFn != nil && setBrightnessFn != nil
    }

    static func canChangeBrightness(for display: CGDirectDisplayID) -> Bool {
        canChangeBrightnessFn?(display) ?? false
    }

    static func getBrightness(for display: CGDirectDisplayID) -> Float? {
        guard let getBrightnessFn else { return nil }
        var value: Float = 0
        let result = getBrightnessFn(display, &value)
        return result == 0 ? value : nil
    }

    @discardableResult
    static func setBrightness(_ value: Float, for display: CGDirectDisplayID) -> Bool {
        guard let setBrightnessFn else { return false }
        return setBrightnessFn(display, value) == 0
    }
}
