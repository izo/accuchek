# Icônes de l'application

## Génération des icônes

Pour générer les icônes de l'application, vous pouvez utiliser la commande Tauri :

```bash
npm run tauri icon path/to/your/icon.png
```

Cette commande nécessite une image PNG de 1024x1024 pixels minimum et génère automatiquement toutes les tailles requises pour chaque plateforme.

## Icônes requises

### macOS
- `icon.icns` - Icône pour l'application macOS

### Windows
- `icon.ico` - Icône pour l'application Windows

### Linux
- `32x32.png`
- `128x128.png`
- `128x128@2x.png`
- `icon.png` - Icône principale (512x512 ou plus)

## Création d'une icône personnalisée

1. Créez une image PNG de 1024x1024 pixels
2. Le design doit être simple et clair, idéalement avec :
   - Un symbole lié à la santé/glucose
   - Les couleurs de la marque AccuChek (bleu)
   - Un fond transparent

3. Utilisez la commande Tauri pour générer toutes les variantes :
   ```bash
   npm run tauri icon src-tauri/icons/app-icon-source.png
   ```

## Icônes par défaut

Pour l'instant, l'application utilisera les icônes par défaut de Tauri. Pour une application de production, il est recommandé de créer des icônes personnalisées.

## Outils recommandés

- **Figma** (gratuit) - Pour créer des designs
- **GIMP** (gratuit) - Pour éditer des images
- **Inkscape** (gratuit) - Pour créer des vecteurs
- **@tauri-apps/cli** - Génération automatique des icônes
