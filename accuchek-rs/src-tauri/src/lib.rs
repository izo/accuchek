mod usb;

use serde::{Deserialize, Serialize};
use tauri::Manager;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GlucoseSample {
    pub id: usize,
    pub epoch: i64,
    pub timestamp: String,
    #[serde(rename = "mg/dL")]
    pub mg_dl: u16,
    #[serde(rename = "mmol/L")]
    pub mmol_l: f64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct DeviceInfo {
    pub name: String,
    pub vendor_id: String,
    pub product_id: String,
}

// Tauri command to scan for AccuChek devices
#[tauri::command]
async fn scan_devices() -> Result<Vec<DeviceInfo>, String> {
    // Initialize logger
    env_logger::Builder::from_default_env()
        .filter_level(log::LevelFilter::Info)
        .try_init()
        .ok();

    // Load device configuration
    let config = usb::load_config().map_err(|e| format!("Failed to load config: {}", e))?;

    // Find all matching devices
    let devices = usb::find_devices(&config)
        .map_err(|e| format!("Failed to find devices: {}", e))?;

    Ok(devices
        .iter()
        .map(|d| DeviceInfo {
            name: d.name.clone(),
            vendor_id: format!("{:04x}", d.vendor_id),
            product_id: format!("{:04x}", d.product_id),
        })
        .collect())
}

// Tauri command to download glucose samples from a device
#[tauri::command]
async fn download_data(device_index: usize) -> Result<Vec<GlucoseSample>, String> {
    // Initialize logger
    env_logger::Builder::from_default_env()
        .filter_level(log::LevelFilter::Info)
        .try_init()
        .ok();

    // Load device configuration
    let config = usb::load_config().map_err(|e| format!("Failed to load config: {}", e))?;

    // Find all matching devices
    let devices = usb::find_devices(&config)
        .map_err(|e| format!("Failed to find devices: {}", e))?;

    if devices.is_empty() {
        return Err("No AccuChek devices found. Make sure the device is connected and in data transfer mode.".to_string());
    }

    if device_index >= devices.len() {
        return Err(format!(
            "Device index {} out of range (found {} devices)",
            device_index,
            devices.len()
        ));
    }

    let device_info = &devices[device_index];

    // Connect and download data
    let samples = usb::download_samples(device_info)
        .map_err(|e| format!("Failed to download samples: {}", e))?;

    Ok(samples)
}

// Tauri command to export data to JSON file
#[tauri::command]
async fn export_json(samples: Vec<GlucoseSample>, filename: String) -> Result<String, String> {
    use std::fs::File;
    use std::io::Write;

    let json = serde_json::to_string_pretty(&samples)
        .map_err(|e| format!("Failed to serialize data: {}", e))?;

    let mut file = File::create(&filename)
        .map_err(|e| format!("Failed to create file: {}", e))?;

    file.write_all(json.as_bytes())
        .map_err(|e| format!("Failed to write file: {}", e))?;

    Ok(format!("Data exported to {}", filename))
}

// Tauri command to export data to CSV file
#[tauri::command]
async fn export_csv(samples: Vec<GlucoseSample>, filename: String) -> Result<String, String> {
    use std::fs::File;
    use std::io::Write;

    let mut csv = String::from("ID,Timestamp,Epoch,mg/dL,mmol/L\n");

    for sample in samples {
        csv.push_str(&format!(
            "{},{},{},{},{:.1}\n",
            sample.id, sample.timestamp, sample.epoch, sample.mg_dl, sample.mmol_l
        ));
    }

    let mut file = File::create(&filename)
        .map_err(|e| format!("Failed to create file: {}", e))?;

    file.write_all(csv.as_bytes())
        .map_err(|e| format!("Failed to write file: {}", e))?;

    Ok(format!("Data exported to {}", filename))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            scan_devices,
            download_data,
            export_json,
            export_csv
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
