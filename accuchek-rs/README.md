# AccuChek-RS - Rust USB Blood Glucose Monitor Utility

A modern, cross-platform Rust implementation for downloading blood glucose samples from Roche Accu-Chek Guide devices via USB.

## Features

- **Pure Rust** - No C dependencies, uses `nusb` for cross-platform USB support
- **Cross-Platform** - Works on Linux, macOS, and Windows
- **Safe** - Memory-safe by design, no buffer overflows or use-after-free bugs
- **Fast** - Optimized release builds with LTO
- **Simple** - Single binary, no runtime dependencies

## Supported Devices

- Roche Accu-Chek Guide (Model 929) - USB ID `173a:21d5`
- Roche Accu-Chek Guide (Alternative) - USB ID `173a:21d7`
- Roche Relion Platinum (Model 982) - USB ID `173a:21d8`

## Installation

### Prerequisites

- Rust 1.70 or later (install from [rustup.rs](https://rustup.rs/))

### Build from Source

```bash
cd accuchek-rs
cargo build --release
```

The compiled binary will be at `target/release/accuchek-rs`

## Usage

### Basic Usage

1. Connect your AccuChek device via USB
2. Make sure the device shows "**data transfer / transferring data**" on screen
3. Run the utility:

```bash
# On Linux, you may need sudo for USB access
sudo ./target/release/accuchek-rs > samples.json

# On macOS, usually no sudo needed
./target/release/accuchek-rs > samples.json
```

### Command Line Options

```bash
# Show help
./accuchek-rs --help

# Verbose mode (shows debug logging)
./accuchek-rs --verbose

# Select specific device (if multiple connected)
./accuchek-rs --device-index 0
```

### Output Format

The utility outputs JSON to stdout:

```json
[
  {
    "id": 0,
    "epoch": 1716720600,
    "timestamp": "2024/05/26 14:30",
    "mg/dL": 125,
    "mmol/L": 6.944444
  },
  ...
]
```

## Platform-Specific Notes

### Linux

On Linux, you may need to run with `sudo` for USB access, or configure udev rules:

```bash
# Create udev rule for AccuChek devices
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="173a", ATTR{idProduct}=="21d5", MODE="0666"' | sudo tee /etc/udev/rules.d/99-accuchek.rules

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### macOS

On macOS, USB access typically doesn't require root privileges. Just run:

```bash
./accuchek-rs > samples.json
```

### Windows

On Windows, you may need to install the WinUSB driver using Zadig:

1. Download [Zadig](https://zadig.akeo.ie/)
2. Connect your AccuChek device
3. In Zadig, select the AccuChek device
4. Choose "WinUSB" driver and click "Install"

## Troubleshooting

### Device Not Found

If the utility can't find your device:

1. Disconnect and reconnect the USB cable
2. Make sure the device screen shows "**data transfer**"
3. Try running with `--verbose` to see detailed logs:
   ```bash
   ./accuchek-rs --verbose 2> debug.log > samples.json
   ```
4. Check that your device is in the supported list

### Timeout Errors

If you get timeout errors:

1. Disconnect the device
2. Reconnect and wait for "data transfer" message
3. Run the utility again immediately

### Multiple Devices

If you have multiple AccuChek devices connected:

```bash
# List all devices (will show count)
./accuchek-rs --verbose

# Select specific device (0-based index)
./accuchek-rs --device-index 1
```

## Technical Details

### Protocol

The utility implements the Continua Health Alliance protocol (ISO/IEEE 11073) used by Roche devices:

1. USB device enumeration and validation
2. Association/pairing handshake
3. Configuration exchange
4. PM Store discovery
5. Segment data transfer
6. Graceful disconnection

### Advantages over C++ Version

- **Cross-platform** - No `#ifdef` for platform differences
- **Memory safe** - No segfaults or buffer overflows
- **Better error handling** - Type-safe `Result<T,E>` instead of error codes
- **Modern build system** - Cargo handles all dependencies
- **No kernel driver issues** - `nusb` handles platform USB differences

### Dependencies

All dependencies are automatically managed by Cargo:

- `nusb` - Pure Rust USB library
- `serde` & `serde_json` - JSON serialization
- `chrono` - Date/time handling
- `log` & `env_logger` - Logging infrastructure
- `anyhow` & `thiserror` - Error handling
- `clap` - Command line parsing

## Development

### Running Tests

```bash
cargo test
```

### Debug Build

```bash
cargo build
./target/debug/accuchek-rs --verbose
```

### Adding New Devices

Edit `config.toml` and add your device's USB IDs:

```toml
[[devices]]
vendor_id = 0x173a
product_id = 0xXXXX
name = "Your Device Name"
```

## License

This is free and unencumbered software released into the public domain (Unlicense).

## Credits

Protocol reverse-engineered from the Tidepool uploader project:
https://github.com/tidepool-org/uploader/tree/master/lib/drivers/roche

Original C++ implementation by the AccuChek project contributors.

## Contributing

Contributions are welcome! Please:

1. Test on your platform
2. Add support for new devices if you can verify they work
3. Submit issues for bugs or enhancement requests
4. Send pull requests with improvements
