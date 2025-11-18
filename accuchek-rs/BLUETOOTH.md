# Support Bluetooth pour AccuChek-RS

## Résumé de la Recherche

### ✅ L'AccuChek Guide supporte Bluetooth BLE

**Caractéristiques identifiées :**
- **Bluetooth Low Energy (BLE)** - Pas Bluetooth Classic
- **Certifié Continua 2014** - Même protocole que USB
- **Portée** : 3 mètres max
- **Pairing** : Passkey pairing requis
- **Apps compatibles** : mySugr, Accu-Chek Connect, Glooko
- **Multi-device** : Jusqu'à 5 appareils pairés

### Crate Rust : btleplug

**Informations clés :**
- **Crate** : `btleplug` (https://github.com/deviceplug/btleplug)
- **Plateformes** : Windows 10+, macOS, Linux, iOS, Android
- **Type** : Async BLE, mode central/host uniquement
- **License** : BSD 3-Clause
- **Note** : BLE uniquement (pas Bluetooth Classic)

## Architecture Proposée

### 1. Abstraction du Transport

Créer un trait `Transport` pour abstraire USB vs Bluetooth :

```rust
// src/transport/mod.rs
use anyhow::Result;

pub trait Transport {
    /// Write data to device
    fn write(&mut self, data: &[u8]) -> Result<usize>;

    /// Read data from device
    fn read(&mut self, buffer: &mut [u8]) -> Result<usize>;

    /// Control transfer (USB specific, no-op for BLE)
    fn control_in(&mut self, buf: &mut [u8]) -> Result<usize> {
        Ok(0) // Default implementation for BLE
    }
}

pub mod usb;
pub mod ble;
```

### 2. Structure du Projet Étendue

```
accuchek-rs/
├── Cargo.toml
├── src/
│   ├── main.rs              # CLI avec choix USB/BLE
│   ├── transport/
│   │   ├── mod.rs           # Trait Transport
│   │   ├── usb.rs           # Implémentation USB (existant)
│   │   └── ble.rs           # Implémentation BLE (nouveau)
│   ├── protocol/
│   │   ├── mod.rs           # Logique protocole Continua (refactorisé)
│   │   └── handler.rs       # ProtocolHandler générique
│   └── device/
│       ├── mod.rs
│       ├── config.rs        # Configuration
│       └── discovery.rs     # Découverte USB + BLE
```

### 3. Implémentation USB (refactorisation)

```rust
// src/transport/usb.rs
use super::Transport;
use anyhow::Result;
use rusb::{DeviceHandle, GlobalContext};
use std::time::Duration;

pub struct UsbTransport {
    handle: DeviceHandle<GlobalContext>,
    bulk_in: u8,
    bulk_out: u8,
    timeout: Duration,
}

impl Transport for UsbTransport {
    fn write(&mut self, data: &[u8]) -> Result<usize> {
        let written = self.handle.write_bulk(self.bulk_out, data, self.timeout)?;
        Ok(written)
    }

    fn read(&mut self, buffer: &mut [u8]) -> Result<usize> {
        let read = self.handle.read_bulk(self.bulk_in, buffer, self.timeout)?;
        Ok(read)
    }

    fn control_in(&mut self, buf: &mut [u8]) -> Result<usize> {
        let result = self.handle.read_control(
            rusb::request_type(
                rusb::Direction::In,
                rusb::RequestType::Standard,
                rusb::Recipient::Device
            ),
            rusb::constants::LIBUSB_REQUEST_GET_STATUS,
            0,
            0,
            buf,
            self.timeout,
        )?;
        Ok(result)
    }
}
```

### 4. Implémentation BLE (nouvelle)

```rust
// src/transport/ble.rs
use super::Transport;
use anyhow::Result;
use btleplug::api::{Central, Peripheral, WriteType};
use btleplug::platform::{Adapter, PeripheralId};
use std::time::Duration;
use uuid::Uuid;

// UUIDs Continua Health Alliance standard
const CONTINUA_SERVICE_UUID: Uuid =
    Uuid::from_u128(0x00001523_1212_efde_1523_785feabcd123); // Example
const CONTINUA_TX_CHAR_UUID: Uuid =
    Uuid::from_u128(0x00001524_1212_efde_1523_785feabcd123);
const CONTINUA_RX_CHAR_UUID: Uuid =
    Uuid::from_u128(0x00001525_1212_efde_1523_785feabcd123);

pub struct BleTransport {
    peripheral: Box<dyn Peripheral>,
    tx_characteristic: btleplug::api::Characteristic,
    rx_characteristic: btleplug::api::Characteristic,
    timeout: Duration,
}

impl BleTransport {
    pub async fn connect(peripheral_id: PeripheralId, adapter: &Adapter) -> Result<Self> {
        // Connexion au périphérique BLE
        let peripheral = adapter.peripheral(&peripheral_id).await?;
        peripheral.connect().await?;

        // Découverte des services
        peripheral.discover_services().await?;

        // Trouver les caractéristiques Continua
        let characteristics = peripheral.characteristics();
        let tx_char = characteristics.iter()
            .find(|c| c.uuid == CONTINUA_TX_CHAR_UUID)
            .ok_or_else(|| anyhow::anyhow!("TX characteristic not found"))?
            .clone();

        let rx_char = characteristics.iter()
            .find(|c| c.uuid == CONTINUA_RX_CHAR_UUID)
            .ok_or_else(|| anyhow::anyhow!("RX characteristic not found"))?
            .clone();

        // S'abonner aux notifications RX
        peripheral.subscribe(&rx_char).await?;

        Ok(Self {
            peripheral: Box::new(peripheral),
            tx_characteristic: tx_char,
            rx_characteristic: rx_char,
            timeout: Duration::from_secs(5),
        })
    }
}

impl Transport for BleTransport {
    fn write(&mut self, data: &[u8]) -> Result<usize> {
        // BLE a des limites de MTU (typiquement 20-512 bytes)
        // Il faut fragmenter si nécessaire
        futures::executor::block_on(async {
            self.peripheral.write(
                &self.tx_characteristic,
                data,
                WriteType::WithResponse
            ).await?;
            Ok(data.len())
        })
    }

    fn read(&mut self, buffer: &mut [u8]) -> Result<usize> {
        // Attendre une notification
        futures::executor::block_on(async {
            let notifications = self.peripheral.notifications().await?;

            // Timeout sur la réception
            let result = tokio::time::timeout(
                self.timeout,
                notifications.recv()
            ).await??;

            let len = result.value.len().min(buffer.len());
            buffer[..len].copy_from_slice(&result.value[..len]);
            Ok(len)
        })
    }
}
```

### 5. Protocole Générique

```rust
// src/protocol/handler.rs
use crate::transport::Transport;
use anyhow::Result;

pub struct ProtocolHandler<T: Transport> {
    transport: T,
    buffer: Vec<u8>,
    invoke_id: u16,
    phase: usize,
}

impl<T: Transport> ProtocolHandler<T> {
    pub fn new(transport: T) -> Self {
        Self {
            transport,
            buffer: vec![0u8; 1024],
            invoke_id: 0,
            phase: 1,
        }
    }

    pub fn execute(&mut self) -> Result<Vec<GlucoseSample>> {
        // Même logique que l'implémentation USB actuelle
        // mais utilise self.transport au lieu de self.handle

        // Phase 1: Initial control transfer (USB only)
        self.transport.control_in(&mut [0u8; 2])?;

        // Phase 2-13: Identique à l'implémentation actuelle
        // mais avec self.transport.write() et self.transport.read()

        // ... (code existant refactorisé)

        todo!()
    }
}
```

### 6. CLI Étendu

```rust
// src/main.rs
use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Connection type
    #[arg(short, long, default_value = "usb")]
    connection: ConnectionType,

    /// Device index to use
    #[arg(short, long)]
    device_index: Option<usize>,

    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,
}

#[derive(Debug, Clone, clap::ValueEnum)]
enum ConnectionType {
    Usb,
    Bluetooth,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    match args.connection {
        ConnectionType::Usb => {
            // Logique USB existante
            usb::download_samples()?;
        }
        ConnectionType::Bluetooth => {
            // Nouvelle logique BLE
            ble::download_samples().await?;
        }
    }

    Ok(())
}
```

## Dépendances Additionnelles

```toml
[dependencies]
# Existantes
rusb = "0.9"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
chrono = "0.4"
log = "0.4"
env_logger = "0.11"
anyhow = "1.0"
thiserror = "1.0"
clap = { version = "4.0", features = ["derive"] }
toml = "0.8"

# Nouvelles pour BLE
btleplug = "0.11"
tokio = { version = "1", features = ["full"] }
futures = "0.3"
uuid = "1.0"
```

## Défis Techniques

### 1. UUIDs Continua

**Problème** : Les UUIDs exacts des services/caractéristiques Continua pour AccuChek ne sont pas publics.

**Solutions** :
- Scanner un device réel avec `nRF Connect` ou similaire
- Reverse engineering via sniffing BLE
- Contacter Roche pour documentation

### 2. MTU Limitations

**Problème** : BLE a des limites de MTU (20-512 bytes) vs USB (64 bytes bulk).

**Solution** :
- Implémenter fragmentation/réassemblage dans `BleTransport`
- Négocier MTU max avec `peripheral.request_mtu()`

### 3. Pairing/Bonding

**Problème** : AccuChek requiert un pairing sécurisé.

**Solution** :
- Implémenter gestion du pairing dans `BleTransport::connect()`
- Stocker les bonds pour reconnexion rapide

### 4. Async vs Sync

**Problème** : `btleplug` est async, `rusb` est sync.

**Solution** :
- Utiliser `futures::executor::block_on` dans `BleTransport`
- Ou passer toute l'app en async (recommandé)

## Plan d'Implémentation

### Phase 1: Refactorisation (1-2 jours)
1. Extraire trait `Transport`
2. Refactoriser code USB existant
3. Rendre `ProtocolHandler` générique

### Phase 2: Découverte BLE (1 jour)
1. Scanner un AccuChek Guide réel
2. Identifier les UUIDs Continua
3. Documenter les caractéristiques

### Phase 3: Implémentation BLE (2-3 jours)
1. Implémenter `BleTransport`
2. Gestion du pairing
3. Gestion de la fragmentation

### Phase 4: Tests & Debug (2-3 jours)
1. Tests avec device réel
2. Comparaison des données USB vs BLE
3. Documentation

**Total estimé** : 6-9 jours

## Utilisation Future

```bash
# USB (existant)
./accuchek-rs --connection usb > samples.json

# Bluetooth
./accuchek-rs --connection bluetooth > samples.json

# Avec index de device
./accuchek-rs --connection bluetooth --device-index 0 --verbose
```

## Notes de Sécurité

- **Pairing requis** : Ne pas stocker les clés en clair
- **Range limité** : 3m max, risque d'interception faible
- **Chiffrement BLE** : Utiliser AES-128 CCM (standard BLE)
- **Validation** : Vérifier que le device est authentique (certificat Continua)

## Conclusion

**Faisabilité** : ✅ Techniquement possible
**Effort** : ~6-9 jours de développement
**Bloqueur principal** : Découverte des UUIDs Continua (requiert un device réel)

**Recommandation** : Commencer par scanner un AccuChek Guide avec `nRF Connect` pour obtenir les UUIDs avant d'implémenter le code.
