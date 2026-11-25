# Llaboratoriu d'accesu remotu llocal (Windows ↔ Linux) con SSH

[Español](README.md) · [English](README.en.md) · [Bable/Asturianu](README.ast.md)

> **Namás pa aprender.** Usa esti proyeutu **namái nos tos equipos o col consentimientu esplícitu y por escritu del dueñu**, y na to rede llocal. Nun tien ocultamientu, persistencia automática, evasión d'antivirus nin saltos d'autenticación.

Esti repositoriu ye un llaboratoriu pequeñu y tresparente pa aprender **ciberseguridá defensiva y alministración de sistemes**: configurar un servidor **OpenSSH** en Windows, coneutar dende **Linux o Windows** con claves criptográfiques, y entender el cortexafuegos, l'autenticación y la llimpieza final.

## Qué incluye

| Elementu | Función |
|---|---|
| `windows/setup-ssh-server.ps1` | Instala y configura OpenSSH Server en Windows, crea un usuariu dedicáu, instala la to clave pública, llinda'l cortexafuegos a la subred de la LAN y pue desface tou con `-Uninstall`. |
| `scripts/generate-key.sh` | Xenera un par de claves Ed25519 (privada y pública). |
| `client/connect.sh` | Cliente pa Linux/macOS/WSL. |
| `client/connect.ps1` | Cliente pa Windows (usa'l `ssh.exe` que yá vien en Windows 10/11). |
| `docs/GUIA_DIDACTICA.*.md` | Guía pasu a pasu en castellán, inglés y bable/asturianu. |
| `.github/workflows/` + `.gitlab-ci.yml` | Espeyu bidireccional automáticu GitHub ⇄ GitLab y lliberaciones. |

## Entamu rápidu

```bash
# 1. Xenerar la clave (nel to equipu de trabayu)
./scripts/generate-key.sh

# 2. Copiar keys/lab_ed25519.pub al equipu Windows de destín y, nesi equipu,
#    como Alministrador:
#    powershell -ExecutionPolicy Bypass -File .\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub

# 3. Coneutar dende Linux/macOS
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519

# 4. Coneutar dende otru Windows
powershell -ExecutionPolicy Bypass -File .\client\connect.ps1 -Host 192.168.1.50 -User labremote -Key .\keys\lab_ed25519
```

Pa desface los cambeos en Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\setup-ssh-server.ps1 -Uninstall
```

## Seguridá por diseñu

- **Consentimientu**: el script ha executase a mano con permisos d'alministrador nel equipu de destín.
- **Ensin contraseñes**: `PasswordAuthentication no`; namás clave pública Ed25519.
- **Ensin esposición a Internet**: regla del cortexafuegos llindada a la subred privada detectada (RFC1918). El cliente alvierte si la IP nun ye privada.
- **Ensin sigilo**: servicios, usuarios, regles y ficheros tán documentaos y puen borrase.
- **Ensin persistencia oculta**: el serviciu arranca en mode `Manual` sacantes pases `-Autostart`.

## Documentación

- [Guía didáctica (bable/asturianu)](docs/GUIA_DIDACTICA.ast.md)
- [Guía didáctica (castellán)](docs/GUIA_DIDACTICA.es.md)
- [Didactic guide (English)](docs/GUIA_DIDACTICA.en.md)
- [Política de seguridá](SECURITY.md)
- [Normes de convivencia](CODE_OF_CONDUCT.md)

## Espeyu y lliberaciones

- GitHub (orixe): `https://github.com/BENDER35/sc-lab-win-loc`
- GitLab (espeyu): `https://gitlab.com/BENDER_5000/sc-lab-win-loc`
- Sincronización bidireccional automática con GitHub Actions + GitLab CI.
- Paquetes ZIP descargables na pestana *Releases* de GitHub.

## Llicencia

MIT. Mira [LICENSE](LICENSE).
