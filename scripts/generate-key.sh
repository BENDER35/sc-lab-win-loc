#!/usr/bin/env bash
# Genera un par de claves Ed25519 para el laboratorio.
# Uso: ./scripts/generate-key.sh  (o KEY_NAME=otra ./scripts/generate-key.sh)
set -euo pipefail

KEY_DIR="${KEY_DIR:-./keys}"
KEY_NAME="${KEY_NAME:-lab_ed25519}"
KEY_PATH="$KEY_DIR/$KEY_NAME"

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

if [[ -e "$KEY_PATH" || -e "$KEY_PATH.pub" ]]; then
  echo "Ya existe una clave en '$KEY_PATH'. Elige otro KEY_NAME o bórrala primero." >&2
  exit 1
fi

if ! command -v ssh-keygen >/dev/null 2>&1; then
  echo "Necesitas ssh-keygen (openssh-client)." >&2
  exit 1
fi

ssh-keygen -t ed25519 -a 100 -f "$KEY_PATH" -C "lab-local-$(date +%Y%m%d)" -N ''
chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

cat <<EOF

Listo.
  Clave privada (NO compartir): $KEY_PATH
  Clave pública  (copiar a Windows): $KEY_PATH.pub

Contenido de la clave pública:
EOF
cat "$KEY_PATH.pub"
