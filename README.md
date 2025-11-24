# AccuChek - Blood Glucose Data Manager

A monorepo containing applications for downloading and managing blood glucose data from Roche AccuChek devices.

## Project Structure

```
accuchek/
├── apps/
│   ├── tauri/              # Tauri desktop app (macOS, Windows, Linux)
│   ├── ios/                # iOS native app (SwiftUI)
│   └── macos-swift/        # macOS native app (SwiftUI)
├── packages/
│   ├── accuchek-core/      # Rust core library (USB communication)
│   └── AccuChekKit/        # Swift package (shared iOS/macOS)
├── legacy/                 # Original C++ implementation
├── Cargo.toml              # Rust workspace configuration
└── README.md
```

## Applications

### Tauri Desktop App (macOS/Windows/Linux)
A cross-platform desktop application built with Tauri and React.

**Features:**
- USB device connection and data download
- JSON/CSV export
- Modern React UI

**Build:**
```bash
cd apps/tauri
npm install
npm run tauri:build
```

### iOS App (SwiftUI)
Native iOS application for iPhone and iPad.

**Features:**
- Bluetooth LE connection to AccuChek devices
- Glucose trend visualization
- History tracking
- Data export

**Build:**
Open `apps/ios/AccuChek/AccuChek.xcodeproj` in Xcode.

### macOS Native App (SwiftUI)
Native macOS application with full desktop integration.

**Features:**
- Bluetooth and USB device support
- Advanced data visualization with charts
- Sidebar navigation
- Native macOS look and feel
- Keyboard shortcuts

**Build:**
Open `apps/macos-swift/AccuChek/AccuChek.xcodeproj` in Xcode.

## Packages

### accuchek-core (Rust)
Core library for USB communication with AccuChek devices.

```bash
# Build CLI tool
cd packages/accuchek-core
cargo build --release

# Run CLI
./target/release/accuchek-cli > samples.json
```

### AccuChekKit (Swift)
Shared Swift package for iOS and macOS apps.

**Contains:**
- `GlucoseSample` - Data model for glucose readings
- `DataManager` - Data persistence and export
- `BluetoothService` - BLE device communication
- Statistics and analytics utilities

## Supported Devices

- Roche AccuChek Guide
- Other compatible devices (see `config.txt`)

## Requirements

### Rust/Tauri Apps
- Rust 1.70+
- Node.js 18+
- libusb (Linux: `libusb-1.0-dev`)

### Swift Apps
- Xcode 15+
- macOS 13+ / iOS 16+

## Development

### Rust Workspace
```bash
# Build all Rust packages
cargo build

# Run tests
cargo test

# Build release
cargo build --release
```

### Swift Package
```bash
cd packages/AccuChekKit
swift build
swift test
```

## Legacy Code

The original C++ implementation is preserved in the `legacy/` directory for reference.

```bash
cd legacy
make
./accuchek > samples.json
```

## Data Format

Glucose readings are exported in JSON format:

```json
[
  {
    "id": 1,
    "epoch": 1700000000,
    "timestamp": "2024-11-14 10:30:00",
    "mg/dL": 105,
    "mmol/L": 5.8
  }
]
```

## Troubleshooting

### USB Connection Issues
1. Disconnect device USB cable
2. Reconnect and ensure device displays "data transfer" mode
3. On Linux, run with `sudo` or configure udev rules

### Bluetooth Issues
1. Ensure Bluetooth is enabled on your device
2. Put AccuChek device in pairing mode
3. Grant Bluetooth permissions to the app

## License

Unlicense - See LICENSE.txt

## Contributing

Pull requests are welcome! Please ensure your changes work with all applications in the monorepo.
