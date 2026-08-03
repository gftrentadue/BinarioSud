#!/usr/bin/env bash
#
# Avvia l'app sul primo device Android FISICO collegato, indipendentemente dal
# modello specifico (non lega l'avvio a un serial). Esclude gli emulatori.
#
# Uso:
#   scripts/run-android-device.sh [argomenti extra per `flutter run`]
# Esempi:
#   scripts/run-android-device.sh                 # debug
#   scripts/run-android-device.sh --profile       # profile mode
#   scripts/run-android-device.sh --release       # release mode
#
set -euo pipefail

# Seleziona il primo device con emulator=false e targetPlatform "android-*".
DEVICE_ID="$(flutter devices --machine | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)
except Exception:
    devices = []
for d in devices:
    if not d.get("emulator", True) and str(d.get("targetPlatform", "")).startswith("android"):
        print(d["id"])
        break
')"

if [ -z "${DEVICE_ID}" ]; then
  echo "❌ Nessun device Android fisico collegato." >&2
  echo "   Collega il telefono via USB con il Debug USB attivo e autorizza il PC," >&2
  echo "   poi verifica con: flutter devices" >&2
  exit 1
fi

echo "▶️  Avvio su device Android reale: ${DEVICE_ID}"
exec flutter run -d "${DEVICE_ID}" "$@"
