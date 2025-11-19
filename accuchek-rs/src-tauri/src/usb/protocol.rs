use super::{AccuChekDevice, UsbError};
use anyhow::Result;
use chrono::{NaiveDateTime, TimeZone};
use log::{debug, info, warn};
use rusb::{Direction, TransferType};
use serde::Serialize;
use std::time::Duration;

const TIMEOUT: Duration = Duration::from_secs(5);
const BUFFER_SIZE: usize = 1024;

// Protocol constants from Continua Health Alliance (ISO/IEEE 11073)
const APDU_TYPE_ASSOCIATION_RESPONSE: u16 = 0xE300;
const APDU_TYPE_ASSOCIATION_RELEASE_REQUEST: u16 = 0xE400;
const APDU_TYPE_PRESENTATION_APDU: u16 = 0xE700;

const DATA_APDU_INVOKE_GET: u16 = 0x0103;
const DATA_APDU_INVOKE_CONFIRMED_ACTION: u16 = 0x0107;
const DATA_APDU_RESPONSE_CONFIRMED_EVENT_REPORT: u16 = 0x0201;

const EVENT_TYPE_MDC_NOTI_CONFIG: u16 = 0x0D1C;
const EVENT_TYPE_MDC_NOTI_SEGMENT_DATA: u16 = 0x0D21;

const ACTION_TYPE_MDC_ACT_SEG_GET_INFO: u16 = 0x0C0D;
const ACTION_TYPE_MDC_ACT_SEG_TRIG_XFER: u16 = 0x0C1C;

const MDC_MOC_VMO_PMSTORE: u16 = 61;

#[derive(Debug, Serialize, Clone)]
pub struct GlucoseSample {
    pub id: usize,
    pub epoch: i64,
    pub timestamp: String,
    #[serde(rename = "mg/dL")]
    pub mg_dl: u16,
    #[serde(rename = "mmol/L")]
    pub mmol_l: f64,
}

/// Download all glucose samples from the device
pub fn download_samples(device_info: &AccuChekDevice) -> Result<Vec<GlucoseSample>> {
    info!("Opening device...");

    // Find the USB device
    let devices = rusb::devices()?;
    let device = devices
        .iter()
        .find(|d| {
            d.bus_number() == device_info.bus && d.address() == device_info.address
        })
        .ok_or(UsbError::DeviceNotFound)?;

    let mut handle = device.open()?;

    info!("Device opened successfully");

    // On Linux, detach kernel driver if attached
    #[cfg(target_os = "linux")]
    {
        match handle.kernel_driver_active(0) {
            Ok(true) => {
                info!("Detaching kernel driver...");
                handle.detach_kernel_driver(0)?;
            }
            _ => {}
        }
    }

    // Set configuration
    info!("Setting configuration...");
    handle.set_active_configuration(1)?;

    // Claim interface 0
    info!("Claiming interface 0...");
    handle.claim_interface(0)?;

    // Set alternate setting
    handle.set_alternate_setting(0, 0)?;

    // AccuChek uses standard bulk endpoints:
    // 0x01 = EP 1 OUT (host to device)
    // 0x81 = EP 1 IN (device to host)
    let bulk_out_endpoint = 0x01;
    let bulk_in_endpoint = 0x81;

    info!("Bulk OUT endpoint: {:02x}", bulk_out_endpoint);
    info!("Bulk IN endpoint: {:02x}", bulk_in_endpoint);

    let mut protocol = ProtocolHandler {
        handle,
        bulk_out: bulk_out_endpoint,
        bulk_in: bulk_in_endpoint,
        buffer: vec![0u8; BUFFER_SIZE],
        invoke_id: 0,
        phase: 1,
    };

    let result = protocol.execute();

    // Release interface
    protocol.handle.release_interface(0)?;

    result
}

struct ProtocolHandler {
    handle: rusb::DeviceHandle<rusb::GlobalContext>,
    bulk_out: u8,
    bulk_in: u8,
    buffer: Vec<u8>,
    invoke_id: u16,
    phase: usize,
}

impl ProtocolHandler {
    fn execute(&mut self) -> Result<Vec<GlucoseSample>> {
        // Phase 1: Initial control transfer
        self.control_transfer_in()?;

        // Phase 2: Wait for pairing request
        self.bulk_in("pairing request", 64)?;

        // Phase 3: Send pairing confirmation
        self.send_pairing_confirmation()?;

        // Phase 4: Receive config info
        let bytes_read = self.bulk_in("config info", BUFFER_SIZE)?;
        self.update_invoke_id(6)?;

        // Parse config to get PM store handle
        let pm_store_handle = self.parse_pm_store_handle(bytes_read)?;
        info!("PM Store handle: {}", pm_store_handle);

        // Phase 5: Send config received confirmation
        self.send_config_confirmation()?;

        // Phase 6: Request MDS attributes
        self.request_mds_attributes()?;

        // Phase 7: Receive MDS response
        self.bulk_in("MDS attribute answer", BUFFER_SIZE)?;
        self.update_invoke_id(6)?;

        // Phase 8: Send action request for segment info
        self.send_segment_info_request(pm_store_handle)?;

        // Phase 9: Receive action response
        self.bulk_in("action request response", BUFFER_SIZE)?;
        self.update_invoke_id(6)?;

        // Phase 10: Request data segments
        self.request_data_segments(pm_store_handle)?;

        // Phase 11: Receive segment headers
        self.bulk_in("segment headers", BUFFER_SIZE)?;
        self.update_invoke_id(6)?;

        // Phase 12: Read all data segments
        let samples = self.read_data_segments(pm_store_handle)?;

        // Phase 13: Disconnect cleanly
        self.disconnect()?;

        Ok(samples)
    }

    fn control_transfer_in(&mut self) -> Result<()> {
        info!("Phase {}: Initial control transfer", self.phase);

        let mut buf = [0u8; 2];
        let result = self.handle.read_control(
            rusb::request_type(Direction::In, rusb::RequestType::Standard, rusb::Recipient::Device),
            rusb::constants::LIBUSB_REQUEST_GET_STATUS,
            0,
            0,
            &mut buf,
            TIMEOUT,
        )?;

        debug!("Control transfer received {} bytes", result);
        self.phase += 1;
        Ok(())
    }

    fn bulk_out(&mut self, name: &str, data: &[u8]) -> Result<()> {
        info!("Phase {}: Sending {}", self.phase, name);
        debug_hex_dump(name, data);

        let written = self.handle.write_bulk(self.bulk_out, data, TIMEOUT)?;

        if written != data.len() {
            return Err(UsbError::Transfer(format!(
                "Wrote {} bytes but expected {}",
                written,
                data.len()
            ))
            .into());
        }

        self.phase += 1;
        Ok(())
    }

    fn bulk_in(&mut self, name: &str, max_len: usize) -> Result<usize> {
        info!("Phase {}: Receiving {}", self.phase, name);

        self.buffer.resize(max_len, 0);
        let bytes_read = self.handle.read_bulk(self.bulk_in, &mut self.buffer[..max_len], TIMEOUT)?;

        debug!("Read {} bytes", bytes_read);
        debug_hex_dump(name, &self.buffer[..bytes_read]);

        self.phase += 1;
        Ok(bytes_read)
    }

    fn update_invoke_id(&mut self, offset: usize) -> Result<()> {
        if self.buffer.len() < offset + 2 {
            return Err(UsbError::Parse("Buffer too small for invoke_id".to_string()).into());
        }

        self.invoke_id = u16::from_be_bytes([self.buffer[offset], self.buffer[offset + 1]]);
        debug!("Updated invoke_id to: {}", self.invoke_id);
        Ok(())
    }

    fn send_pairing_confirmation(&mut self) -> Result<()> {
        let mut msg = Vec::new();
        write_be16(&mut msg, APDU_TYPE_ASSOCIATION_RESPONSE);
        write_be16(&mut msg, 44); // length
        write_be16(&mut msg, 0x0003); // accepted-unknown-config
        write_be16(&mut msg, 20601); // data-proto-id
        write_be16(&mut msg, 38); // data-proto-info length
        write_be32(&mut msg, 0x80000002); // protocolVersion
        write_be16(&mut msg, 0x8000); // encoding-rules = MDER
        write_be32(&mut msg, 0x80000000); // nomenclatureVersion
        write_be32(&mut msg, 0); // functionalUnits
        write_be32(&mut msg, 0x80000000); // systemType
        write_be16(&mut msg, 8); // system-id length
        write_be32(&mut msg, 0x12345678); // system-id high
        write_be32(&mut msg, 0); // padding
        write_be32(&mut msg, 0); // padding
        write_be32(&mut msg, 0); // padding
        write_be16(&mut msg, 0); // padding

        self.bulk_out("pairing confirmation", &msg)
    }

    fn parse_pm_store_handle(&self, bytes_read: usize) -> Result<u16> {
        // Look for PM Store object in config
        let mut offset = 24;

        if bytes_read < offset + 4 {
            return Err(UsbError::Parse("Config response too small".to_string()).into());
        }

        let count = u16::from_be_bytes([self.buffer[offset], self.buffer[offset + 1]]);
        offset += 4; // skip count and dummy

        debug!("Config has {} objects", count);

        for i in 0..count {
            if offset + 8 > bytes_read {
                break;
            }

            let obj_class = u16::from_be_bytes([self.buffer[offset], self.buffer[offset + 1]]);
            let obj_handle = u16::from_be_bytes([self.buffer[offset + 2], self.buffer[offset + 3]]);
            let _attr_count = u16::from_be_bytes([self.buffer[offset + 4], self.buffer[offset + 5]]);
            let obj_size = u16::from_be_bytes([self.buffer[offset + 6], self.buffer[offset + 7]]);

            debug!(
                "Object {}: class={}, handle={}, size={}",
                i, obj_class, obj_handle, obj_size
            );

            if obj_class == MDC_MOC_VMO_PMSTORE {
                return Ok(obj_handle);
            }

            offset += 8 + obj_size as usize;
        }

        Err(UsbError::Parse("PM Store not found in config".to_string()).into())
    }

    fn send_config_confirmation(&mut self) -> Result<()> {
        let mut msg = Vec::new();
        write_be16(&mut msg, APDU_TYPE_PRESENTATION_APDU);
        write_be16(&mut msg, 22);
        write_be16(&mut msg, 20);
        write_be16(&mut msg, self.invoke_id);
        write_be16(&mut msg, DATA_APDU_RESPONSE_CONFIRMED_EVENT_REPORT);
        write_be16(&mut msg, 14);
        write_be16(&mut msg, 0); // obj-handle
        write_be32(&mut msg, 0); // currentTime
        write_be16(&mut msg, EVENT_TYPE_MDC_NOTI_CONFIG);
        write_be16(&mut msg, 4);
        write_be16(&mut msg, 0x4000); // config-report-id
        write_be16(&mut msg, 0); // config-result = accepted

        self.bulk_out("config confirmation", &msg)
    }

    fn request_mds_attributes(&mut self) -> Result<()> {
        let mut msg = Vec::new();
        write_be16(&mut msg, APDU_TYPE_PRESENTATION_APDU);
        write_be16(&mut msg, 14);
        write_be16(&mut msg, 12);
        write_be16(&mut msg, self.invoke_id + 1);
        write_be16(&mut msg, DATA_APDU_INVOKE_GET);
        write_be16(&mut msg, 6);
        write_be16(&mut msg, 0); // obj-handle
        write_be32(&mut msg, 0); // currentTime

        self.bulk_out("MDS attribute request", &msg)
    }

    fn send_segment_info_request(&mut self, pm_store_handle: u16) -> Result<()> {
        let mut msg = Vec::new();
        write_be16(&mut msg, APDU_TYPE_PRESENTATION_APDU);
        write_be16(&mut msg, 20);
        write_be16(&mut msg, 18);
        write_be16(&mut msg, self.invoke_id + 1);
        write_be16(&mut msg, DATA_APDU_INVOKE_CONFIRMED_ACTION);
        write_be16(&mut msg, 12);
        write_be16(&mut msg, pm_store_handle);
        write_be16(&mut msg, ACTION_TYPE_MDC_ACT_SEG_GET_INFO);
        write_be16(&mut msg, 6);
        write_be16(&mut msg, 1); // all segments
        write_be16(&mut msg, 2);
        write_be16(&mut msg, 0);

        self.bulk_out("action request", &msg)
    }

    fn request_data_segments(&mut self, pm_store_handle: u16) -> Result<()> {
        let mut msg = Vec::new();
        write_be16(&mut msg, APDU_TYPE_PRESENTATION_APDU);
        write_be16(&mut msg, 16);
        write_be16(&mut msg, 14);
        write_be16(&mut msg, self.invoke_id + 1);
        write_be16(&mut msg, DATA_APDU_INVOKE_CONFIRMED_ACTION);
        write_be16(&mut msg, 8);
        write_be16(&mut msg, pm_store_handle);
        write_be16(&mut msg, ACTION_TYPE_MDC_ACT_SEG_TRIG_XFER);
        write_be16(&mut msg, 2);
        write_be16(&mut msg, 0); // segment

        self.bulk_out("request segments", &msg)
    }

    fn read_data_segments(&mut self, pm_store_handle: u16) -> Result<Vec<GlucoseSample>> {
        let mut samples = Vec::new();
        let mut sample_id = 0;

        loop {
            // Read segment data
            let bytes_read = self.bulk_in("data segment", BUFFER_SIZE)?;

            if bytes_read < 33 {
                warn!("Segment too small: {} bytes", bytes_read);
                break;
            }

            let status = self.buffer[32];
            self.update_invoke_id(6)?;

            // Extract data for ACK
            let u0 = u32::from_be_bytes([
                self.buffer[22],
                self.buffer[23],
                self.buffer[24],
                self.buffer[25],
            ]);
            let u1 = u32::from_be_bytes([
                self.buffer[26],
                self.buffer[27],
                self.buffer[28],
                self.buffer[29],
            ]);
            let u2 = u16::from_be_bytes([self.buffer[30], self.buffer[31]]);

            // Parse samples from segment
            let segment_samples = self.parse_segment_samples(&mut sample_id, bytes_read)?;
            samples.extend(segment_samples);

            // Send ACK
            self.send_segment_ack(pm_store_handle, u0, u1, u2)?;

            // Check if this was the last segment
            if status & 0x40 != 0 {
                info!("Last segment received");
                break;
            }
        }

        Ok(samples)
    }

    fn parse_segment_samples(
        &self,
        sample_id: &mut usize,
        bytes_read: usize,
    ) -> Result<Vec<GlucoseSample>> {
        let mut samples = Vec::new();

        if bytes_read < 32 {
            return Ok(samples);
        }

        let nb_entries = u16::from_be_bytes([self.buffer[30], self.buffer[31]]) as usize;
        info!("Segment has {} entries", nb_entries);

        let mut offset = 30;

        for _ in 0..nb_entries {
            if offset + 18 > bytes_read {
                break;
            }

            // Decode BCD-encoded datetime
            let cc = bcd_decode(self.buffer[offset + 6]);
            let yy = bcd_decode(self.buffer[offset + 7]);
            let mm = bcd_decode(self.buffer[offset + 8]);
            let dd = bcd_decode(self.buffer[offset + 9]);
            let hh = bcd_decode(self.buffer[offset + 10]);
            let mn = bcd_decode(self.buffer[offset + 11]);

            // Read glucose value and status
            let vv = u16::from_be_bytes([self.buffer[offset + 14], self.buffer[offset + 15]]);
            let ss = u16::from_be_bytes([self.buffer[offset + 16], self.buffer[offset + 17]]);

            offset += 12;

            debug!(
                "Sample: {:02}{:02}/{:02}/{:02} {:02}:{:02} => mg/dL={}, status=0x{:02x}",
                cc, yy, mm, dd, hh, mn, vv, ss
            );

            // Only include valid samples (status == 0)
            if ss == 0 {
                let year = cc * 100 + yy;
                let timestamp = format!("{:02}{:02}/{:02}/{:02} {:02}:{:02}", cc, yy, mm, dd, hh, mn);

                // Create naive datetime and convert to epoch
                let naive_dt = NaiveDateTime::parse_from_str(
                    &format!("{}-{:02}-{:02} {:02}:{:02}:00", year, mm, dd, hh, mn),
                    "%Y-%m-%d %H:%M:%S",
                )?;

                let epoch = chrono::Local.from_local_datetime(&naive_dt).unwrap().timestamp();

                samples.push(GlucoseSample {
                    id: *sample_id,
                    epoch,
                    timestamp,
                    mg_dl: vv,
                    mmol_l: vv as f64 / 18.0,
                });

                *sample_id += 1;
            }
        }

        Ok(samples)
    }

    fn send_segment_ack(&mut self, pm_store_handle: u16, u0: u32, u1: u32, u2: u16) -> Result<()> {
        let mut msg = Vec::new();
        write_be16(&mut msg, APDU_TYPE_PRESENTATION_APDU);
        write_be16(&mut msg, 30);
        write_be16(&mut msg, 28);
        write_be16(&mut msg, self.invoke_id);
        write_be16(&mut msg, DATA_APDU_RESPONSE_CONFIRMED_EVENT_REPORT);
        write_be16(&mut msg, 22);
        write_be16(&mut msg, pm_store_handle);
        write_be32(&mut msg, 0xFFFFFFFF); // relative time
        write_be16(&mut msg, EVENT_TYPE_MDC_NOTI_SEGMENT_DATA);
        write_be16(&mut msg, 12);
        write_be32(&mut msg, u0);
        write_be32(&mut msg, u1);
        write_be16(&mut msg, u2);
        write_be16(&mut msg, 0x0080);

        self.bulk_out("segment ACK", &msg)
    }

    fn disconnect(&mut self) -> Result<()> {
        let mut msg = Vec::new();
        write_be16(&mut msg, APDU_TYPE_ASSOCIATION_RELEASE_REQUEST);
        write_be16(&mut msg, 2);
        write_be16(&mut msg, 0); // normal release

        self.bulk_out("release request", &msg)?;
        self.bulk_in("release confirmation", BUFFER_SIZE)?;

        info!("Disconnected cleanly");
        Ok(())
    }
}

// Helper functions for writing big-endian values
fn write_be16(buf: &mut Vec<u8>, val: u16) {
    buf.extend_from_slice(&val.to_be_bytes());
}

fn write_be32(buf: &mut Vec<u8>, val: u32) {
    buf.extend_from_slice(&val.to_be_bytes());
}

// Decode BCD (Binary-Coded Decimal)
fn bcd_decode(val: u8) -> i32 {
    let high = (val >> 4) & 0x0F;
    let low = val & 0x0F;
    (high * 10 + low) as i32
}

fn debug_hex_dump(name: &str, data: &[u8]) {
    if !log::log_enabled!(log::Level::Debug) {
        return;
    }

    debug!("=== {} ({} bytes) ===", name, data.len());

    for (i, chunk) in data.chunks(16).enumerate() {
        let mut hex = String::new();
        let mut ascii = String::new();

        for &byte in chunk.iter() {
            hex.push_str(&format!("{:02X} ", byte));
            ascii.push(if byte.is_ascii_graphic() || byte == b' ' {
                byte as char
            } else {
                '.'
            });
        }

        // Pad if last line
        if chunk.len() < 16 {
            for _ in 0..(16 - chunk.len()) {
                hex.push_str("   ");
            }
        }

        debug!("{:04x}  {}  {}", i * 16, hex, ascii);
    }
}
