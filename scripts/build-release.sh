#!/usr/bin/env bash
# Construit l'AAB (Play Store) et l'APK (site web) signés.
# Usage : scripts/build-release.sh https://api.mon-domaine.com/api/v1 [https://site-taara.com]
set -euo pipefail
cd "$(dirname "$0")/.."

API_URL="${1:-}"
[ -n "$API_URL" ] || { echo "Usage : $0 https://api.mon-domaine.com/api/v1"; exit 1; }
case "$API_URL" in https://*) ;; *) echo "L'URL de l'API doit être en HTTPS."; exit 1;; esac
[ -f android/key.properties ] || { echo "Clé absente : lancez d'abord scripts/creer-cle-signature.sh"; exit 1; }

# La clé Gemini n'est PAS intégrée : l'app passe par le backend (/ai/generate)
SITE_URL="${2:-}"
DEFINES=(--dart-define=TAARA_API_URL="$API_URL" --dart-define=GEMINI_API_KEY= --dart-define=TAARA_SITE_URL="$SITE_URL")

flutter build appbundle --release "${DEFINES[@]}"
flutter build apk --release "${DEFINES[@]}"

echo
echo "Play Store : build/app/outputs/bundle/release/app-release.aab"
echo "Site web   : build/app/outputs/flutter-apk/app-release.apk"
