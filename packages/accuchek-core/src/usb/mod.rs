mod device;
mod protocol;

pub use device::{find_devices, load_config, AccuChekDevice};
pub use protocol::download_samples;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum UsbError {
    #[error("USB error: {0}")]
    Usb(#[from] rusb::Error),

    #[error("Device not found")]
    DeviceNotFound,

    #[error("Transfer error: {0}")]
    Transfer(String),

    #[error("Protocol error: {0}")]
    Protocol(String),

    #[error("Parse error: {0}")]
    Parse(String),

    #[error("Timeout")]
    Timeout,
}
