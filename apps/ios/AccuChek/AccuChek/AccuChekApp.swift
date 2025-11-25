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
        }
    }
}
