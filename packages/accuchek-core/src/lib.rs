//! AccuChek Core Library
//!
//! This library provides functionality to communicate with Roche AccuChek
//! blood glucose monitoring devices via USB.

pub mod usb;

use serde::{Deserialize, Serialize};

/// Represents a single blood glucose reading
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GlucoseSample {
    pub id: usize,
    pub epoch: i64,
    pub timestamp: String,
    #[serde(rename = "mg/dL")]
    pub mg_dl: u16,
    #[serde(rename = "mmol/L")]
    pub mmol_l: f64,
}

/// Represents information about a connected AccuChek device
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub name: String,
    pub vendor_id: u16,
    pub product_id: u16,
}

/// Configuration for supported device IDs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceConfig {
    pub devices: Vec<SupportedDevice>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SupportedDevice {
    pub name: String,
    pub vendor_id: u16,
    pub product_id: u16,
}

// Re-export main functions
pub use usb::{find_devices, load_config, download_samples, AccuChekDevice};

/// Library version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
