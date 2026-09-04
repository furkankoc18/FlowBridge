import AppKit
import SwiftUI

@main
struct FlowBridgeMacApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("FlowBridge", id: "dashboard") {
            DashboardView()
                .environmentObject(model)
                .frame(minWidth: 860, minHeight: 590)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 680)

        MenuBarExtra("FlowBridge", systemImage: "rectangle.2.swap") {
            MenuBarView()
                .environmentObject(model)
        }
    }
}
private struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Label(
                model.discoveryStatus.title,
                systemImage: model.isRunning ? "checkmark.circle.fill" : "pause.circle"
            )
            .foregroundStyle(.secondary)

            Divider()

            Button("FlowBridge'i Aç") {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button(model.isRunning ? "Paylaşımı Durdur" : "Paylaşımı Başlat") {
                model.toggleRunning()
            }

            Divider()

            Button("Çıkış") { NSApp.terminate(nil) }
        }
    }
}
