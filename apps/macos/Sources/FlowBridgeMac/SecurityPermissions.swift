import AppKit
import ApplicationServices
import CoreGraphics

enum SecurityPermissions {
    static var accessibility: PermissionState {
        AXIsProcessTrusted() ? .granted : .missing
    }

    static var inputMonitoring: PermissionState {
        CGPreflightListenEventAccess() ? .granted : .missing
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }

    static func openAccessibilitySettings() {
        openSettings(anchor: "Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openSettings(anchor: "Privacy_ListenEvent")
    }

    private static func openSettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
