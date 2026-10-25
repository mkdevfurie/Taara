#!/usr/bin/env bash
# Crée la clé de signature Play Store (« upload key ») et android/key.properties.
# À lancer UNE SEULE FOIS. Le mot de passe est demandé par keytool (rien n'est affiché).
set -euo pipefail

DOSSIER="${1:-$HOME/Documents/Taara/signature}"
CLE="$DOSSIER/taara-upload.jks"
PROPS="$(cd "$(dirname "$0")/.." && pwd)/android/key.properties"

if [ -f "$CLE" ]; then
  echo "Une clé existe déjà : $CLE — rien n'est modifié."
  exit 1
fi

mkdir -p "$DOSSIER" && chmod 700 "$DOSSIER"
echo "Choisissez un mot de passe solide (12 caractères minimum) et notez-le dans un coffre-fort."
read -rsp "Mot de passe : " PW; echo
read -rsp "Confirmez    : " PW2; echo
[ "$PW" = "$PW2" ] || { echo "Les mots de passe ne correspondent pas."; exit 1; }
[ ${#PW} -ge 12 ] || { echo "12 caractères minimum."; exit 1; }

keytool -genkeypair -keystore "$CLE" -storetype JKS -keyalg RSA -keysize 4096 \
  -validity 10000 -alias upload -storepass "$PW" -keypass "$PW" \
  -dname "CN=mkdevfurie, OU=Taara, O=Taara, L=Lome, C=TG"

umask 077
cat > "$PROPS" <<PROPS
storePassword=$PW
keyPassword=$PW
keyAlias=upload
storeFile=$CLE
PROPS
chmod 600 "$CLE" "$PROPS"

echo
echo "✅ Clé créée : $CLE"
echo "✅ $PROPS (ignoré par git)"
echo "⚠️  Sauvegardez $DOSSIER (clé USB + coffre-fort) : sans cette clé, plus de mises à jour."
