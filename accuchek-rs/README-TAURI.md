# AccuChek Data Manager - Application Tauri

Application de bureau multiplateforme pour télécharger et exporter les données de glycémie depuis les appareils AccuChek Guide.

## Caractéristiques

- ✅ Interface graphique moderne et intuitive
- ✅ Détection automatique des appareils AccuChek connectés
- ✅ Téléchargement des mesures de glycémie via USB
- ✅ Export des données en JSON et CSV
- ✅ Support macOS, Linux et Windows
- ✅ Interface en français

## Appareils supportés

- **Accu-Chek Guide** (Model 929)
- **Accu-Chek Guide** (Alternative)
- **Roche Relion Platform** (Model 982)

## Prérequis

### Développement

- **Node.js** 18+ et npm
- **Rust** 1.70+ (via [rustup](https://rustup.rs/))
- **Dépendances système** :
  - **macOS** : Xcode Command Line Tools (`xcode-select --install`)
  - **Linux** : `libusb-1.0-dev`, `build-essential`, `libssl-dev`, `libgtk-3-dev`, `libwebkit2gtk-4.0-dev`
  - **Windows** : Microsoft Visual Studio C++ Build Tools

### Installation Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install libusb-1.0-0-dev build-essential libssl-dev libgtk-3-dev libwebkit2gtk-4.0-dev libappindicator3-dev librsvg2-dev patchelf
```

## Installation et développement

### 1. Cloner le projet

```bash
git clone <votre-repo>
cd accuchek/accuchek-rs
```

### 2. Installer les dépendances

```bash
npm install
```

### 3. Lancer en mode développement

```bash
npm run tauri:dev
```

L'application se lance automatiquement avec hot-reload activé.

## Build de production

### Build pour votre plateforme

```bash
npm run tauri:build
```

Les binaires seront générés dans :
- **macOS** : `src-tauri/target/release/bundle/dmg/`
- **Linux** : `src-tauri/target/release/bundle/deb/` ou `appimage/`
- **Windows** : `src-tauri/target/release/bundle/msi/`

## Configuration macOS

### Permissions USB

L'application inclut déjà les entitlements nécessaires pour l'accès USB sur macOS dans le fichier `src-tauri/entitlements.plist` :

```xml
<key>com.apple.security.device.usb</key>
<true/>
```

### Signature et notarisation (pour distribution)

Pour distribuer l'application sur macOS, vous devez :

1. **Obtenir un certificat Apple Developer**
2. **Configurer la signature** dans `src-tauri/tauri.conf.json` :

```json
{
  "bundle": {
    "macOS": {
      "signingIdentity": "Developer ID Application: Votre Nom (TEAM_ID)",
      "providerShortName": "TEAM_ID"
    }
  }
}
```

3. **Notariser l'application** :

```bash
# Après le build
xcrun notarytool submit "src-tauri/target/release/bundle/dmg/AccuChek_0.1.0_aarch64.dmg" \
  --apple-id "votre@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait
```

## Configuration Linux

### Règles udev

Pour accéder aux appareils USB sans `sudo` sur Linux, créez le fichier `/etc/udev/rules.d/99-accuchek.rules` :

```
# Accu-Chek Guide (Model 929)
SUBSYSTEM=="usb", ATTR{idVendor}=="173a", ATTR{idProduct}=="21d5", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="173a", ATTR{idProduct}=="21d7", MODE="0666"

# Relion Platinum (Model 982)
SUBSYSTEM=="usb", ATTR{idVendor}=="173a", ATTR{idProduct}=="21d8", MODE="0666"
```

Puis rechargez les règles :

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Configuration Windows

Sur Windows, vous devrez peut-être installer le driver WinUSB pour votre appareil AccuChek en utilisant [Zadig](https://zadig.akeo.ie/).

## Utilisation

### 1. Connecter votre appareil

Connectez votre AccuChek Guide via USB et mettez-le en **mode transfert de données**.

### 2. Rechercher les appareils

Cliquez sur le bouton **"Rechercher"** pour détecter les appareils connectés.

### 3. Télécharger les données

Une fois l'appareil détecté, cliquez sur **"Télécharger"** pour récupérer vos mesures de glycémie.

### 4. Exporter les données

Vous pouvez exporter vos données dans deux formats :
- **JSON** : Format structuré pour les développeurs ou l'analyse
- **CSV** : Compatible avec Excel, Google Sheets, etc.

## Structure du projet

```
accuchek-rs/
├── src-tauri/              # Code Rust (backend)
│   ├── src/
│   │   ├── lib.rs         # Commandes Tauri
│   │   ├── main.rs        # Point d'entrée
│   │   └── usb/           # Communication USB
│   ├── Cargo.toml
│   ├── tauri.conf.json    # Configuration Tauri
│   └── entitlements.plist # Permissions macOS
│
├── ui/                     # Interface React (frontend)
│   ├── src/
│   │   ├── App.tsx        # Composant principal
│   │   ├── App.css        # Styles
│   │   └── main.tsx       # Point d'entrée React
│   └── index.html
│
├── package.json
├── vite.config.ts
└── tsconfig.json
```

## Commandes Tauri disponibles

### `scan_devices()`
Recherche tous les appareils AccuChek connectés.

**Retourne** : `Vec<DeviceInfo>`

### `download_data(device_index: number)`
Télécharge les mesures de glycémie depuis l'appareil sélectionné.

**Retourne** : `Vec<GlucoseSample>`

### `export_json(samples: Vec<GlucoseSample>, filename: string)`
Exporte les données au format JSON.

**Retourne** : `string` (message de confirmation)

### `export_csv(samples: Vec<GlucoseSample>, filename: string)`
Exporte les données au format CSV.

**Retourne** : `string` (message de confirmation)

## Format des données

### GlucoseSample

```json
{
  "id": 1,
  "epoch": 1700000000,
  "timestamp": "2023-11-14 20:13:20",
  "mg/dL": 120,
  "mmol/L": 6.7
}
```

## Dépannage

### macOS : "AccuChek.app cannot be opened"

Si l'application ne s'ouvre pas en raison des restrictions de sécurité :

```bash
xattr -cr /Applications/AccuChek.app
```

### Linux : Permission denied

Si vous obtenez une erreur de permission USB, vérifiez que les règles udev sont correctement installées.

### Aucun appareil trouvé

1. Vérifiez que l'appareil est connecté et allumé
2. Assurez-vous qu'il est en mode transfert de données
3. Essayez de déconnecter et reconnecter l'appareil
4. Sur Linux, vérifiez les règles udev
5. Sur Windows, vérifiez que le driver WinUSB est installé

## Roadmap

### v0.2.0 (Prévu)
- [ ] Support Bluetooth Low Energy (BLE)
- [ ] Détection automatique USB/BLE
- [ ] Interface pour régler l'heure de l'appareil

### v0.3.0 (Futur)
- [ ] Graphiques et statistiques
- [ ] Support multi-appareils simultanés
- [ ] Synchronisation cloud (optionnelle)
- [ ] Formats d'export additionnels (XML, PDF)

## Contribuer

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir des issues ou des pull requests.

## Licence

Ce projet est sous licence **Unlicense** (domaine public).

## Support

Pour toute question ou problème, ouvrez une issue sur GitHub.
