#!/usr/bin/env bash
# Crea un ZIP limpio (sin .git ni claves locales) del estado actual del repo.
# Uso: ./scripts/release-zip.sh [v1.0.0]
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
cd "$ROOT"

VERSION="${1:-v1.0.0}"
OUT_DIR="${OUT_DIR:-$ROOT/dist}"
NAME="sc-lab-win-loc-${VERSION}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git archive --format=tar HEAD | tar -x -C "$TMP"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/${NAME}.zip"
(cd "$TMP" && zip -q -r "$OUT_DIR/${NAME}.zip" .)

echo "ZIP creado: $OUT_DIR/${NAME}.zip"
unzip -l "$OUT_DIR/${NAME}.zip" | tail -3
