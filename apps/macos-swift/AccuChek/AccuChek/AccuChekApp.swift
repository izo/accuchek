import SwiftUI
import AccuChekKit

@main
struct AccuChekApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var bluetoothService = BluetoothService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(bluetoothService)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Data") {
                Button("Sync from Device") {
                    bluetoothService.startScanning()
                }
                .keyboardShortcut("R", modifiers: [.command])

                Divider()

                Button("Export as JSON...") {
                    // Export action
                }
                .keyboardShortcut("E", modifiers: [.command])

                Button("Export as CSV...") {
                    // Export action
                }
                .keyboardShortcut("E", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(dataManager)
        }
    }
}
