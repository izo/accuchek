use anyhow::Result;
use log::{debug, info};
use serde::Deserialize;
use std::fs;

#[derive(Debug, Clone)]
pub struct AccuChekDevice {
    pub vendor_id: u16,
    pub product_id: u16,
    pub name: String,
    pub bus: u8,
    pub address: u8,
}

#[derive(Debug, Deserialize)]
pub struct DeviceConfig {
    pub devices: Vec<SupportedDevice>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct SupportedDevice {
    pub vendor_id: u16,
    pub product_id: u16,
    pub name: String,
}

/// Load device configuration from config.toml
pub fn load_config() -> Result<DeviceConfig> {
    let config_path = "config.toml";

    // Try current directory first
    let config_content = if std::path::Path::new(config_path).exists() {
        fs::read_to_string(config_path)?
    } else {
        // Fallback to hardcoded configuration
        include_str!("../../config.toml").to_string()
    };

    let config: DeviceConfig = toml::from_str(&config_content)?;
    info!("Loaded configuration with {} supported devices", config.devices.len());

    Ok(config)
}

/// Find all AccuChek devices connected to the system
pub fn find_devices(config: &DeviceConfig) -> Result<Vec<AccuChekDevice>> {
    let mut found_devices = Vec::new();

    info!("Scanning for USB devices...");

    let devices = rusb::devices()?;

    for device in devices.iter() {
        let desc = device.device_descriptor()?;

        debug!(
            "Checking device: vendor={:04x}, product={:04x}",
            desc.vendor_id(),
            desc.product_id()
        );

        // Check if this device matches our supported devices
        if let Some(supported) = config.devices.iter().find(|d| {
            d.vendor_id == desc.vendor_id() && d.product_id == desc.product_id()
        }) {
            // Verify device configuration matches AccuChek specs
            if is_valid_accuchek(&device)? {
                info!(
                    "Found matching device: {} (vendor={:04x}, product={:04x})",
                    supported.name,
                    desc.vendor_id(),
                    desc.product_id()
                );

                found_devices.push(AccuChekDevice {
                    vendor_id: desc.vendor_id(),
                    product_id: desc.product_id(),
                    name: supported.name.clone(),
                    bus: device.bus_number(),
                    address: device.address(),
                });
            }
        }
    }

    Ok(found_devices)
}

/// Verify if a device matches AccuChek hardware specifications
fn is_valid_accuchek(device: &rusb::Device<rusb::GlobalContext>) -> Result<bool> {
    // AccuChek devices should have:
    // - 1 configuration
    // - 1 interface with 1 alternate setting
    // - 2 bulk endpoints (one in, one out) with 64-byte packet size

    let desc = device.device_descriptor()?;

    if desc.num_configurations() != 1 {
        return Ok(false);
    }

    let config_desc = device.config_descriptor(0)?;

    if config_desc.num_interfaces() != 1 {
        return Ok(false);
    }

    // Check first interface
    let interface = config_desc.interfaces().next();
    if interface.is_none() {
        return Ok(false);
    }

    let interface = interface.unwrap();
    let descriptors: Vec<_> = interface.descriptors().collect();

    if descriptors.len() != 1 {
        return Ok(false);
    }

    let alt_setting = &descriptors[0];

    if alt_setting.num_endpoints() != 2 {
        return Ok(false);
    }

    // Check endpoints
    let mut has_bulk_in = false;
    let mut has_bulk_out = false;

    for endpoint in alt_setting.endpoint_descriptors() {
        if endpoint.max_packet_size() == 64
            && endpoint.transfer_type() == rusb::TransferType::Bulk
        {
            match endpoint.direction() {
                rusb::Direction::In => has_bulk_in = true,
                rusb::Direction::Out => has_bulk_out = true,
            }
        }
    }

    Ok(has_bulk_in && has_bulk_out)
}
