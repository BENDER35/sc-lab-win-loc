# Local remote-access lab (Windows ↔ Linux) using SSH

[Español](README.md) · [English](README.en.md) · [Bable/Asturianu](README.ast.md)

> **Educational use only.** Use this project **only on devices you own or with the explicit, written consent of the owner**, and only on your own local network. It contains no stealth, no automatic persistence, no antivirus evasion and no authentication bypass.

This repository is a small, transparent lab for learning **defensive security and system administration**: install an **OpenSSH** server on Windows, connect from **Linux or Windows** using cryptographic keys, and understand firewalls, authentication and cleanup.

## What is included?

| Component | Purpose |
|---|---|
| `windows/setup-ssh-server.ps1` | Installs/configures OpenSSH Server on Windows, creates a dedicated user, installs your public key, restricts the firewall to your LAN subnet, and can undo everything with `-Uninstall`. |
| `scripts/generate-key.sh` | Generates an Ed25519 key pair (private + public). |
| `client/connect.sh` | Client for Linux/macOS/WSL. |
| `client/connect.ps1` | Client for Windows (uses the `ssh.exe` bundled with Windows 10/11). |
| `docs/GUIA_DIDACTICA.*.md` | Step-by-step guide in Spanish, English and Asturian (bable). |
| `.github/workflows/` + `.gitlab-ci.yml` | Automatic bidirectional GitHub ⇄ GitLab mirror and releases. |

## Quick start

```bash
# 1. Generate a key (on your workstation)
./scripts/generate-key.sh

# 2. Copy keys/lab_ed25519.pub to the target Windows machine and, on that machine,
#    as Administrator:
#    powershell -ExecutionPolicy Bypass -File .\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub

# 3. Connect from Linux/macOS
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519

# 4. Connect from another Windows machine
powershell -ExecutionPolicy Bypass -File .\client\connect.ps1 -Host 192.168.1.50 -User labremote -Key .\keys\lab_ed25519
```

To revert all changes on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\setup-ssh-server.ps1 -Uninstall
```

## Security by design

- **Consent**: the script must be run manually with admin rights on the target machine.
- **No passwords**: `PasswordAuthentication no`; Ed25519 public-key only.
- **No Internet exposure**: firewall rule scoped to the detected private subnet (RFC1918). The client warns if the IP is not private.
- **No stealth**: services, users, firewall rules and files are documented and removable.
- **No hidden persistence**: the service starts in `Manual` mode unless `-Autostart` is passed.

## Documentation

- [Didactic guide (English)](docs/GUIA_DIDACTICA.en.md)
- [Guía didáctica (español)](docs/GUIA_DIDACTICA.es.md)
- [Guía didáctica (bable/asturianu)](docs/GUIA_DIDACTICA.ast.md)
- [Security policy](SECURITY.md)
- [Code of conduct](CODE_OF_CONDUCT.md)

## Mirror and releases

- GitHub (source): `https://github.com/BENDER35/sc-lab-win-loc`
- GitLab (mirror): `https://gitlab.com/BENDER_5000/sc-lab-win-loc`
- Automatic bidirectional sync via GitHub Actions + GitLab CI.
- Downloadable ZIP packages on the GitHub *Releases* tab.

## License

MIT. See [LICENSE](LICENSE).
