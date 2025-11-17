# AccuChek-RS Roadmap

## Version Actuelle : 0.1.0

### ✅ Implémenté

- [x] Support USB complet avec rusb
- [x] Protocole Continua Health Alliance
- [x] Détection et validation des devices
- [x] Parsing des données de glycémie
- [x] Export JSON
- [x] CLI avec clap
- [x] Logging configurable
- [x] Cross-platform (Linux, macOS, Windows)
- [x] Documentation complète (README, MIGRATION)

## Version 0.2.0 - Support Bluetooth (En planification)

### Prérequis
- [ ] Scanner un AccuChek Guide réel avec nRF Connect
- [ ] Documenter les UUIDs Continua exacts
- [ ] Valider que le protocole est identique USB/BLE

### Tâches d'implémentation

#### Phase 1: Refactorisation Architecture (1-2 jours)
- [ ] Créer module `src/transport/`
- [ ] Définir trait `Transport`
- [ ] Migrer code USB vers `transport::usb`
- [ ] Rendre `ProtocolHandler` générique sur `Transport`
- [ ] Tests unitaires avec Mock transport

#### Phase 2: Découverte BLE (1 jour)
- [ ] Scanner AccuChek Guide avec nRF Connect app
- [ ] Documenter Service UUIDs
- [ ] Documenter Characteristic UUIDs (TX/RX)
- [ ] Identifier MTU et capacités
- [ ] Tester le pairing

#### Phase 3: Implémentation BLE (2-3 jours)
- [ ] Ajouter dépendance `btleplug = "0.11"`
- [ ] Ajouter dépendance `tokio = { version = "1", features = ["full"] }`
- [ ] Implémenter `BleTransport`
  - [ ] Connexion et découverte
  - [ ] Gestion du pairing
  - [ ] Write avec fragmentation MTU
  - [ ] Read avec buffering de notifications
- [ ] Implémenter `ble::discover_devices()`
- [ ] Étendre CLI pour choix USB/BLE

#### Phase 4: Tests (2-3 jours)
- [ ] Tests USB vs BLE avec même device
- [ ] Validation des données identiques
- [ ] Tests de robustesse (déconnexions)
- [ ] Tests multi-plateforme
- [ ] Documentation et exemples

### Dépendances supplémentaires

```toml
[dependencies]
# Nouvelles
btleplug = "0.11"
tokio = { version = "1", features = ["full"] }
futures = "0.3"
uuid = "1.0"
```

### Notes d'implémentation

**UUIDs Continua** (à confirmer avec device réel):
```rust
// Ces UUIDs sont des EXEMPLES - doivent être découverts
const CONTINUA_SERVICE_UUID: Uuid =
    Uuid::from_u128(0x00001523_1212_efde_1523_785feabcd123);
const CONTINUA_TX_CHAR_UUID: Uuid =
    Uuid::from_u128(0x00001524_1212_efde_1523_785feabcd123);
const CONTINUA_RX_CHAR_UUID: Uuid =
    Uuid::from_u128(0x00001525_1212_efde_1523_785feabcd123);
```

**Utilisation future**:
```bash
# USB (existant)
./accuchek-rs --connection usb > samples.json

# Bluetooth (v0.2.0)
./accuchek-rs --connection bluetooth > samples.json

# Auto-detect (v0.3.0?)
./accuchek-rs --auto > samples.json
```

## Version 0.3.0 - Améliorations (Future)

### Fonctionnalités possibles
- [ ] Auto-détection USB ou BLE
- [ ] Support de plusieurs devices simultanés
- [ ] Export vers formats alternatifs (CSV, XML)
- [ ] Synchronisation cloud (optionnel)
- [ ] Interface graphique (GUI avec egui?)
- [ ] Support Accu-Chek Mobile/Instant
- [ ] Réglage de l'heure du device
- [ ] Effacement de la mémoire
- [ ] Statistiques et graphiques

### Optimisations techniques
- [ ] Cache des devices découverts
- [ ] Reconnexion automatique
- [ ] Streaming des données (pas besoin de tout charger en RAM)
- [ ] Compression des logs
- [ ] Profiling et optimisation

## Contribution

### Processus de développement
1. Fork du repo
2. Créer une branche feature
3. Implémenter + tests
4. Documentation
5. Pull Request

### Standards de code
- Rust 2021 edition
- `cargo fmt` pour le formatage
- `cargo clippy` pour le linting
- Tests unitaires requis
- Documentation inline avec exemples

### Testing
```bash
# Tests unitaires
cargo test

# Tests d'intégration
cargo test --test integration

# Tests avec device réel
cargo run --release -- --verbose --connection usb

# Benchmarks (si applicable)
cargo bench
```

## Maintenance

### Support des plateformes
- **Linux** : Ubuntu 20.04+, Debian 11+, Arch, Fedora
- **macOS** : Big Sur (11) ou plus récent
- **Windows** : Windows 10/11

### Dépendances
- Mise à jour trimestrielle des dépendances
- Audit de sécurité avec `cargo audit`
- Vérification des breaking changes

### Releases
- Semantic versioning (semver)
- Changelog détaillé
- Binaries pré-compilés pour chaque plateforme
- Release notes avec migration guide si nécessaire

## Ressources

### Documentation
- [Continua Health Alliance](https://www.pchalliance.org/)
- [IEEE 11073 Standards](http://11073.org)
- [btleplug Documentation](https://docs.rs/btleplug)
- [rusb Documentation](https://docs.rs/rusb)

### Outils utiles
- **nRF Connect** : Scanner BLE pour mobile
- **Wireshark** : Sniffing USB/Bluetooth
- **bluetoothctl** : CLI Bluetooth Linux
- **Zadig** : Driver USB Windows

### Communauté
- Issues GitHub pour bugs/features
- Discussions pour questions
- PRs bienvenues!

## Timeline estimée

```
Semaines 1-2:  Refactorisation architecture + tests
Semaine 3:     Découverte BLE avec device réel
Semaines 4-5:  Implémentation BLE
Semaine 6:     Tests, documentation, release 0.2.0
```

**Total: ~6 semaines pour version 0.2.0**

## Blockers potentiels

1. **Accès au device physique** - Requis pour découvrir UUIDs
2. **Protocole BLE différent** - Si Roche utilise un protocole propriétaire sur BLE
3. **Pairing complexe** - Si le mécanisme de pairing est non-standard
4. **Permissions macOS** - Peut nécessiter signing du binary
5. **MTU limitations** - Si les messages dépassent MTU max

## Next Steps (Immédiat)

Pour commencer l'implémentation BLE:

1. **Obtenir un AccuChek Guide** avec support Bluetooth
2. **Installer nRF Connect** sur smartphone
3. **Scanner le device** et documenter:
   - Service UUIDs
   - Characteristic UUIDs
   - Propriétés (Read/Write/Notify)
   - MTU
4. **Créer une issue GitHub** avec les UUIDs découverts
5. **Commencer la Phase 1** (refactorisation)

---

*Dernière mise à jour: 2025-11-17*
