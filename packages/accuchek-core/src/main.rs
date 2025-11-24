mod usb;

use anyhow::Result;
use clap::Parser;
use log::{info, warn};
use serde::{Deserialize, Serialize};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Device index to use (default: first found)
    #[arg(short, long)]
    device_index: Option<usize>,

    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,
}

#[derive(Debug, Serialize, Deserialize)]
struct GlucoseSample {
    id: usize,
    epoch: i64,
    timestamp: String,
    #[serde(rename = "mg/dL")]
    mg_dl: u16,
    #[serde(rename = "mmol/L")]
    mmol_l: f64,
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Initialize logger
    if args.verbose {
        env_logger::Builder::from_default_env()
            .filter_level(log::LevelFilter::Debug)
            .init();
    } else {
        env_logger::Builder::from_default_env()
            .filter_level(log::LevelFilter::Warn)
            .init();
    }

    info!("AccuChek Rust - Starting");

    // Load device configuration
    let config = usb::load_config()?;

    // Find all matching devices
    let devices = usb::find_devices(&config)?;

    if devices.is_empty() {
        warn!("No AccuChek devices found");
        anyhow::bail!("No devices found. Make sure the device is connected and in data transfer mode.");
    }

    info!("Found {} device(s)", devices.len());

    // Select device
    let device_index = args.device_index.unwrap_or(0);
    if device_index >= devices.len() {
        anyhow::bail!(
            "Device index {} out of range (found {} devices)",
            device_index,
            devices.len()
        );
    }

    let device_info = &devices[device_index];
    info!("Using device: {}", device_info.name);

    // Connect and download data
    let samples = usb::download_samples(device_info)?;

    // Output JSON
    if !args.verbose {
        println!("{}", serde_json::to_string_pretty(&samples)?);
    } else {
        eprintln!("\n=== Downloaded {} samples ===", samples.len());
        println!("{}", serde_json::to_string_pretty(&samples)?);
    }

    info!("AccuChek Rust - Done");
    Ok(())
}
