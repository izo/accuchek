import SwiftUI
import AccuChekKit

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "wave.3.right")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Latest Reading Card
                    if let latest = dataManager.samples.last {
                        LatestReadingCard(sample: latest)
                    } else {
                        EmptyStateCard()
                    }

                    // Statistics Card
                    if !dataManager.samples.isEmpty {
                        StatisticsCard(
                            statistics: dataManager.statistics(for: dataManager.samples)
                        )
                    }

                    // Quick Actions
                    QuickActionsView()
                }
                .padding()
            }
            .navigationTitle("AccuChek")
        }
    }
}

struct LatestReadingCard: View {
    let sample: GlucoseSample

    var body: some View {
        VStack(spacing: 12) {
            Text("Latest Reading")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(sample.mgDL)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(colorForCategory(sample.category))

            Text("mg/dL")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(sample.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)

            CategoryBadge(category: sample.category)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func colorForCategory(_ category: GlucoseCategory) -> Color {
        switch category {
        case .low: return .blue
        case .normal: return .green
        case .elevated: return .orange
        case .high: return .red
        }
    }
}

struct CategoryBadge: View {
    let category: GlucoseCategory

    var body: some View {
        Text(category.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    var backgroundColor: Color {
        switch category {
        case .low: return .blue
        case .normal: return .green
        case .elevated: return .orange
        case .high: return .red
        }
    }
}

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "drop.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Readings Yet")
                .font(.headline)

            Text("Connect your AccuChek device to sync your glucose readings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatisticsCard: View {
    let statistics: GlucoseStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatItem(title: "Average", value: String(format: "%.0f", statistics.average), unit: "mg/dL")
                StatItem(title: "In Range", value: String(format: "%.0f%%", statistics.inRange), unit: "")
                StatItem(title: "Min", value: "\(statistics.min)", unit: "mg/dL")
                StatItem(title: "Max", value: "\(statistics.max)", unit: "mg/dL")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct QuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                ActionButton(
                    title: "Sync",
                    systemImage: "arrow.triangle.2.circlepath",
                    action: {}
                )

                ActionButton(
                    title: "Export",
                    systemImage: "square.and.arrow.up",
                    action: {}
                )

                ActionButton(
                    title: "Add",
                    systemImage: "plus",
                    action: {}
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)

                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Devices View

struct DevicesView: View {
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if bluetoothService.isScanning {
                        HStack {
                            ProgressView()
                            Text("Scanning for devices...")
                                .foregroundStyle(.secondary)
                        }
                    } else if bluetoothService.discoveredDevices.isEmpty {
                        Text("No devices found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bluetoothService.discoveredDevices) { device in
                            DeviceRow(device: device)
                        }
                    }
                } header: {
                    Text("Available Devices")
                }

                Section {
                    ConnectionStatusRow(state: bluetoothService.connectionState)
                } header: {
                    Text("Connection Status")
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        bluetoothService.startScanning()
                    } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                    .disabled(bluetoothService.isScanning)
                }
            }
            .onAppear {
                bluetoothService.start()
            }
        }
    }
}

struct DeviceRow: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    let device: DiscoveredDevice

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)

                Text("Signal: \(device.rssi) dBm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Connect") {
                bluetoothService.connect(to: device)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

struct ConnectionStatusRow: View {
    let state: ConnectionState

    var body: some View {
        HStack {
            Circle()
                .fill(colorForState)
                .frame(width: 10, height: 10)

            Text(state.rawValue)
        }
    }

    var colorForState: Color {
        switch state {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected: return .green
        }
    }
}

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationStack {
            List {
                ForEach(dataManager.samples) { sample in
                    SampleRow(sample: sample)
                }
            }
            .navigationTitle("History")
            .overlay {
                if dataManager.samples.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("Your glucose readings will appear here")
                    )
                }
            }
        }
    }
}

struct SampleRow: View {
    let sample: GlucoseSample

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sample.mgDL) mg/dL")
                    .font(.headline)

                Text(sample.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CategoryBadge(category: sample.category)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Data") {
                    NavigationLink {
                        Text("Export Settings")
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink {
                        Text("Import Settings")
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                }

                Section("App") {
                    NavigationLink {
                        Text("Units Settings")
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }

                    NavigationLink {
                        Text("Target Range Settings")
                    } label: {
                        Label("Target Range", systemImage: "target")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AccuChekKit.version)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(DataManager())
        .environmentObject(BluetoothService())
}
