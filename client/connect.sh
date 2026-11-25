#!/usr/bin/env bash
# Cliente SSH para Linux/macOS/WSL. Solo redes privadas (RFC1918).
set -euo pipefail

usage() {
  cat <<EOF
Uso: $0 -H <ip> -u <usuario> -k <clave_privada> [opciones]

Opciones:
  -H  IP o nombre del host Windows
  -u  Usuario remoto (por defecto: labremote)
  -k  Ruta a la clave privada
  -p  Puerto SSH (por defecto: 22)
  -c  Comando único a ejecutar (opcional)
  -a  Permitir IPs públicas (NO recomendado; solo si sabes lo que haces)
  -h  Ayuda
EOF
}

HOST=''; USER_NAME='labremote'; KEY=''; PORT='22'; CMD=''; ALLOW_PUBLIC=0
while getopts ':H:u:k:p:c:ah' opt; do
  case "$opt" in
    H) HOST="$OPTARG" ;;
    u) USER_NAME="$OPTARG" ;;
    k) KEY="$OPTARG" ;;
    p) PORT="$OPTARG" ;;
    c) CMD="$OPTARG" ;;
    a) ALLOW_PUBLIC=1 ;;
    h) usage; exit 0 ;;
    :) echo "Falta valor para -$OPTARG" >&2; usage >&2; exit 2 ;;
    \?) echo "Opción desconocida: -$OPTARG" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$HOST" || -z "$KEY" ]]; then
  echo "Faltan -H y -k." >&2; usage >&2; exit 2
fi
if [[ ! -f "$KEY" ]]; then
  echo "No encuentro la clave privada: $KEY" >&2; exit 2
fi
if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Puerto no válido: $PORT" >&2; exit 2
fi

is_private() {
  local ip="$1"
  [[ "$ip" =~ ^10\. ]] || \
  [[ "$ip" =~ ^192\.168\. ]] || \
  [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]
}

if ! is_private "$HOST"; then
  if [[ "$ALLOW_PUBLIC" -eq 0 ]]; then
    echo "AVISO: '$HOST' no parece una IP privada (RFC1918)." >&2
    echo "Este laboratorio es solo para la red local. Usa -a solo bajo tu responsabilidad." >&2
    exit 3
  fi
  echo "AVISO: conectando a una IP pública con -a. ¡Asegúrate de tener autorización!" >&2
fi

KNOWN_HOSTS="${KNOWN_HOSTS:-$HOME/.ssh/known_hosts_lab}"
mkdir -p "$(dirname "$KNOWN_HOSTS")"

args=(
  -i "$KEY"
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=accept-new
  -o "UserKnownHostsFile=$KNOWN_HOSTS"
  -o ForwardAgent=no
  -p "$PORT"
  "$USER_NAME@$HOST"
)
[[ -n "$CMD" ]] && args+=("$CMD")

echo "Conectando a $USER_NAME@$HOST:$PORT ..." >&2
exec ssh "${args[@]}"
