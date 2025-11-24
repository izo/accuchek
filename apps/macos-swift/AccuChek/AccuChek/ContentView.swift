import SwiftUI
import AccuChekKit

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var selectedTab: SidebarItem = .dashboard

    enum SidebarItem: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case history = "History"
        case devices = "Devices"
        case export = "Export"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "chart.line.uptrend.xyaxis"
            case .history: return "clock"
            case .devices: return "wave.3.right"
            case .export: return "square.and.arrow.up"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedTab) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            switch selectedTab {
            case .dashboard:
                DashboardView()
            case .history:
                HistoryView()
            case .devices:
                DevicesView()
            case .export:
                ExportView()
            case .settings:
                SettingsView()
            }
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Stats
                HStack(spacing: 20) {
                    if let latest = dataManager.samples.last {
                        StatCard(
                            title: "Latest Reading",
                            value: "\(latest.mgDL)",
                            unit: "mg/dL",
                            color: colorForCategory(latest.category)
                        )
                    }

                    let stats = dataManager.statistics(for: dataManager.samples)
                    StatCard(
                        title: "Average",
                        value: String(format: "%.0f", stats.average),
                        unit: "mg/dL",
                        color: .blue
                    )

                    StatCard(
                        title: "In Range",
                        value: String(format: "%.0f%%", stats.inRange),
                        unit: "",
                        color: .green
                    )

                    StatCard(
                        title: "Readings",
                        value: "\(stats.count)",
                        unit: "total",
                        color: .purple
                    )
                }
                .padding(.horizontal)

                // Chart placeholder
                GroupBox {
                    VStack {
                        if dataManager.samples.isEmpty {
                            ContentUnavailableView(
                                "No Data",
                                systemImage: "chart.line.uptrend.xyaxis",
                                description: Text("Connect your device to see glucose trends")
                            )
                            .frame(height: 300)
                        } else {
                            GlucoseChartView(samples: dataManager.samples)
                                .frame(height: 300)
                        }
                    }
                } label: {
                    Label("Glucose Trend", systemImage: "chart.line.uptrend.xyaxis")
                }
                .padding(.horizontal)

                // Recent Readings
                GroupBox {
                    if dataManager.samples.isEmpty {
                        Text("No readings available")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(dataManager.samples.suffix(10).reversed()) { sample in
                                ReadingRow(sample: sample)
                                if sample.id != dataManager.samples.first?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } label: {
                    Label("Recent Readings", systemImage: "list.bullet")
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
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

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(color)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GlucoseChartView: View {
    let samples: [GlucoseSample]

    var body: some View {
        // Simple chart representation
        GeometryReader { geometry in
            let maxValue = CGFloat(samples.map { Int($0.mgDL) }.max() ?? 200)
            let minValue = CGFloat(samples.map { Int($0.mgDL) }.min() ?? 50)
            let range = maxValue - minValue

            ZStack {
                // Target range background
                Rectangle()
                    .fill(Color.green.opacity(0.1))
                    .frame(
                        height: geometry.size.height * CGFloat(126 - 70) / range
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * (1 - CGFloat(98 - minValue) / range)
                    )

                // Line chart
                Path { path in
                    let points = samples.enumerated().map { (index, sample) -> CGPoint in
                        let x = CGFloat(index) / CGFloat(samples.count - 1) * geometry.size.width
                        let y = geometry.size.height * (1 - (CGFloat(sample.mgDL) - minValue) / range)
                        return CGPoint(x: x, y: y)
                    }

                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.blue, lineWidth: 2)

                // Data points
                ForEach(Array(samples.enumerated()), id: \.element.id) { index, sample in
                    let x = CGFloat(index) / CGFloat(samples.count - 1) * geometry.size.width
                    let y = geometry.size.height * (1 - (CGFloat(sample.mgDL) - minValue) / range)

                    Circle()
                        .fill(colorForCategory(sample.category))
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }
            }
        }
        .padding()
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

struct ReadingRow: View {
    let sample: GlucoseSample

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sample.formattedDate)
                    .font(.headline)

                Text(sample.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(sample.mgDL)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(colorForCategory(sample.category))

                Text("mg/dL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
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

// MARK: - History View

struct HistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedDateRange: DateRange = .all

    enum DateRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }

    var filteredSamples: [GlucoseSample] {
        dataManager.samples.filter { sample in
            if !searchText.isEmpty {
                return sample.timestamp.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("Date Range", selection: $selectedDateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)

                Spacer()
            }
            .padding()
            .background(.regularMaterial)

            // Table
            Table(filteredSamples) {
                TableColumn("Date") { sample in
                    Text(sample.formattedDate)
                }
                .width(min: 150)

                TableColumn("mg/dL") { sample in
                    Text("\(sample.mgDL)")
                        .foregroundStyle(colorForCategory(sample.category))
                        .fontWeight(.semibold)
                }
                .width(80)

                TableColumn("mmol/L") { sample in
                    Text(String(format: "%.1f", sample.mmolL))
                }
                .width(80)

                TableColumn("Category") { sample in
                    Text(sample.category.rawValue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(colorForCategory(sample.category).opacity(0.2))
                        .clipShape(Capsule())
                }
                .width(100)
            }
        }
        .navigationTitle("History")
        .searchable(text: $searchText, prompt: "Search readings...")
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

// MARK: - Devices View

struct DevicesView: View {
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        VStack(spacing: 0) {
            // Connection Status Banner
            HStack {
                Circle()
                    .fill(colorForState(bluetoothService.connectionState))
                    .frame(width: 10, height: 10)

                Text(bluetoothService.connectionState.rawValue)
                    .font(.headline)

                Spacer()

                if bluetoothService.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning...")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Scan for Devices") {
                        bluetoothService.startScanning()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            // Device List
            List {
                Section("Available Devices") {
                    if bluetoothService.discoveredDevices.isEmpty && !bluetoothService.isScanning {
                        Text("No devices found. Make sure your AccuChek device is in pairing mode.")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(bluetoothService.discoveredDevices) { device in
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
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("USB Devices") {
                    Text("USB device support is available in the Tauri desktop app")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Devices")
        .onAppear {
            bluetoothService.start()
        }
    }

    func colorForState(_ state: ConnectionState) -> Color {
        switch state {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected: return .green
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var exportFormat: ExportFormat = .json
    @State private var dateRange: DateRange = .all
    @State private var showingExportSuccess = false

    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
    }

    enum DateRange: String, CaseIterable {
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case all = "All Data"
    }

    var body: some View {
        Form {
            Section("Export Format") {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Date Range") {
                Picker("Range", selection: $dateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Preview") {
                Text("\(dataManager.samples.count) readings will be exported")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Export") {
                        exportData()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Export Data")
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {}
        }
    }

    func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = exportFormat == .json ? [.json] : [.commaSeparatedText]
        panel.nameFieldStringValue = "accuchek-data.\(exportFormat.rawValue.lowercased())"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                if exportFormat == .json {
                    try dataManager.saveSamples(dataManager.samples, to: url)
                } else {
                    try dataManager.saveAsCSV(dataManager.samples, to: url)
                }
                showingExportSuccess = true
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("glucoseUnit") private var glucoseUnit = "mg/dL"
    @AppStorage("targetLow") private var targetLow = 70
    @AppStorage("targetHigh") private var targetHigh = 126

    var body: some View {
        Form {
            Section("Units") {
                Picker("Glucose Unit", selection: $glucoseUnit) {
                    Text("mg/dL").tag("mg/dL")
                    Text("mmol/L").tag("mmol/L")
                }
            }

            Section("Target Range") {
                HStack {
                    Text("Low")
                    Spacer()
                    TextField("Low", value: $targetLow, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("mg/dL")
                }

                HStack {
                    Text("High")
                    Spacer()
                    TextField("High", value: $targetHigh, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("mg/dL")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AccuChekKit.version)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Platform")
                    Spacer()
                    Text("macOS (Native)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 400)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(DataManager())
        .environmentObject(BluetoothService())
}
