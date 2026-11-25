# Laboratorio de acceso remoto local (Windows ↔ Linux) con SSH

[Español](README.md) · [English](README.en.md) · [Bable/Asturianu](README.ast.md)

> **Solo fines didácticos.** Usa este proyecto **únicamente en equipos de tu propiedad o con consentimiento explícito y por escrito del propietario**, y dentro de tu propia red local. No incluye ocultamiento, persistencia automática, evasión de antivirus ni salto de autenticación.

Este repositorio contiene un laboratorio pequeño y transparente para aprender **ciberseguridad defensiva y administración de sistemas**: configurar un servidor **OpenSSH** en Windows, conectarse desde **Linux o Windows** con claves criptográficas, entender el firewall, la autenticación y la limpieza posterior.

## ¿Qué hace?

| Componente | Función |
|---|---|
| `windows/setup-ssh-server.ps1` | Instala y configura OpenSSH Server en Windows, crea un usuario dedicado, instala tu clave pública, restringe el firewall a tu subred LAN y permite desinstalar todo con `-Uninstall`. |
| `scripts/generate-key.sh` | Genera un par de claves Ed25519 (privada + pública). |
| `client/connect.sh` | Cliente para Linux/macOS/WSL. |
| `client/connect.ps1` | Cliente para Windows (usa el `ssh.exe` incluido en Windows 10/11). |
| `docs/GUIA_DIDACTICA.*.md` | Guía paso a paso en español, inglés y bable/asturianu. |
| `.github/workflows/` + `.gitlab-ci.yml` | Espejo bidireccional automático GitHub ⇄ GitLab y releases. |

## Inicio rápido

```bash
# 1. Generar clave (en tu máquina de trabajo)
./scripts/generate-key.sh

# 2. Copiar keys/lab_ed25519.pub al equipo Windows de destino y, en ese equipo,
#    como Administrador:
#    powershell -ExecutionPolicy Bypass -File .\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub

# 3. Conectar desde Linux/macOS
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519

# 4. Conectar desde otro Windows
powershell -ExecutionPolicy Bypass -File .\client\connect.ps1 -Host 192.168.1.50 -User labremote -Key .\keys\lab_ed25519
```

Para revertir los cambios en Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\setup-ssh-server.ps1 -Uninstall
```

## Seguridad por diseño

- **Consentimiento**: el script debe ejecutarse manualmente con privilegios de administrador en el equipo destino.
- **Sin contraseñas**: `PasswordAuthentication no`; solo clave pública Ed25519.
- **Sin exposición a Internet**: regla de firewall limitada a la subred privada detectada (RFC1918). El cliente avisa si la IP no es privada.
- **Sin sigilo**: servicios, usuarios, reglas de firewall y archivos están documentados y se pueden eliminar.
- **Sin persistencia oculta**: el servicio arranca en `Manual` salvo que pases `-Autostart`.

## Documentación

- [Guía didáctica (español)](docs/GUIA_DIDACTICA.es.md)
- [Didactic guide (English)](docs/GUIA_DIDACTICA.en.md)
- [Guía didáctica (bable/asturianu)](docs/GUIA_DIDACTICA.ast.md)
- [Política de seguridad](SECURITY.md)
- [Reglas de convivencia](CODE_OF_CONDUCT.md)

## Espejo y releases

- GitHub (origen): `https://github.com/BENDER35/sc-lab-win-loc`
- GitLab (espejo): `https://gitlab.com/BENDER_5000/sc-lab-win-loc`
- Sincronización bidireccional automática mediante GitHub Actions + GitLab CI.
- Paquetes ZIP descargables en la pestaña *Releases* de GitHub.

## Licencia

MIT. Consulta [LICENSE](LICENSE).
