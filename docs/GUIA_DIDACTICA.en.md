# Didactic guide: local SSH lab Windows ↔ Linux

## 0. Before you start: ethics and scope

This lab is designed for **learning at home, on your own network**. Before running any script, follow these rules:

1. Only use devices **you own** or for which you have **explicit authorization**.
2. Keep the target machine on a **private** network (home, classroom, isolated lab). No port forwarding from the router to the Internet.
3. Explain what you do and why. The point is to understand, not to hide.
4. When you finish, **undo the changes** (section 8). A good administrator leaves the system as found.

> This project does not evade antivirus, does not create hidden scheduled tasks, does not modify the Registry for silent startup and does not harvest credentials. If you need "access" to someone else's machine, the right answer is to ask permission.

## 1. Requirements

- A machine running **Windows 10/11 or Windows Server** (the "server").
- A machine running **Linux, macOS or Windows** (the "client"), on the same network.
- **Administrator** access on the Windows machine (to install the service).
- PowerShell 5.1+ on Windows; Bash on Linux/macOS.
- Optional: Wireshark to inspect the handshake (you will see no passwords, because there are none).

## 2. Mini-theory: what SSH is

SSH (Secure Shell) is an **encrypted remote administration** protocol. It replaced old Telnet, which sent everything in clear text.

| Concept | Explanation |
|---|---|
| Private key | Secret file kept by the client (`lab_ed25519`). Nobody else should read it (`chmod 600`). |
| Public key | File you copy to the server (`lab_ed25519.pub`). Safe to share. |
| `authorized_keys` | On Windows, the list of public keys allowed for a user. |
| `sshd` | The SSH server service listening on port 22. |
| Firewall | Rule deciding which IPs may connect. Here we scope it to your subnet. |
| Ed25519 | Elliptic-curve algorithm, shorter and stronger than 1024/2048-bit RSA. |

The client proves it owns the private key; the server verifies the signature with the public key. **The private key never leaves the client.**

## 3. Step 1: generate the key pair

On your client machine:

```bash
git clone https://github.com/BENDER35/sc-lab-win-loc.git
cd sc-lab-win-loc
./scripts/generate-key.sh
```

Expected output:

```text
Private key: ./keys/lab_ed25519
Public key:  ./keys/lab_ed25519.pub
```

Copy `keys/lab_ed25519.pub` to the Windows machine (USB, shared folder, `scp` from an already authorized machine...). **Do not copy the private key.**

## 4. Step 2: configure the Windows server

On the Windows machine, open **PowerShell as Administrator** and go to the project folder:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub
```

The script:

1. Detects your IP and mask and computes the subnet (e.g. `192.168.1.0/24`).
2. Installs the *OpenSSH Server* capability if missing.
3. Creates local user `labremote` with a random password (not used).
4. Writes the public key to `C:\Users\labremote\.ssh\authorized_keys` and fixes its ACL.
5. Configures `sshd_config`: `PubkeyAuthentication yes`, `PasswordAuthentication no`, `AllowUsers labremote`.
6. Creates firewall rule `SSHD-Lab` **only for the detected subnet**.
7. Starts the `sshd` service in **Manual** mode (use `-Autostart` to start it with Windows).

Write down the printed IP. Example:

```text
Server ready at 192.168.1.50 (subnet 192.168.1.0/24)
User: labremote
```

To make the service start automatically after a reboot (useful in a lab, but more persistent):

```powershell
.\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub -Autostart
```

## 5. Step 3: connect from Linux

```bash
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519
```

The first time you will see a *host key* warning; that is normal, answer `yes`. Inside, try:

```powershell
whoami
Get-ComputerInfo | Select-Object CsName, WindowsProductName
Get-NetTCPConnection -State Listen | Select-Object -First 5 LocalAddress, LocalPort
exit
```

Run a single command without an interactive session:

```bash
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519 -c "whoami"
```

## 6. Step 4: connect from another Windows machine

Windows 10/11 already ships the OpenSSH client. From PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\client\connect.ps1 -Host 192.168.1.50 -User labremote -Key .\keys\lab_ed25519
```

On older machines, install *OpenSSH Client* under **Settings → Apps → Optional features**.

## 7. Verification and suggested exercises

### Verification

- `Get-Service sshd` on the server should be `Running`.
- `Get-NetFirewallRule -Name SSHD-Lab` should exist with `RemoteAddress` set to your subnet.
- On the client, `ssh -v ...` shows `Authentication succeeded (publickey)`.

### Exercises

1. **Change the key**: generate another key with `KEY_NAME=other_key ./scripts/generate-key.sh`, install it too, and confirm both work.
2. **Break authentication**: rename `authorized_keys` on the server and verify the connection fails. Restore it.
3. **Watch the encryption**: filter `tcp.port == 22` in Wireshark. You will see packets, but no clear-text commands.
4. **Firewall**: temporarily change `RemoteAddress` to an IP that is not yours and confirm you can no longer connect. Restore the rule.
5. **Logs**: inspect `C:\ProgramData\ssh\Logs` (if enabled) or the Event Viewer.

## 8. Cleanup (very important)

On the Windows machine, as Administrator:

```powershell
.\windows\setup-ssh-server.ps1 -Uninstall
```

This stops the service, removes the firewall rule, deletes the `labremote` user and restores `sshd_config` from the `.lab-bak` copy. Also delete the `keys` folder on the client if you no longer need it.

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Connection timed out` | Firewall or wrong IP | Check `ipconfig` on the server and the `SSHD-Lab` rule. |
| `Permission denied (publickey)` | Public key copied wrongly or bad ACL | Recheck `authorized_keys` and rerun the script with `-Force`. |
| `sshd` will not start | Duplicated configuration | Restore from `sshd_config.lab-bak` and rerun. |
| Client warns about a public IP | You are outside the LAN | Stop: this lab is not meant for the Internet. |
| `Set-ExecutionPolicy` blocked | Organization policy | Use `-Scope Process`; do not change the global policy. |

## 10. What NOT to do

- Do not expose port 22 to the Internet.
- Do not reuse the same private key on several machines.
- Do not disable the antivirus or the whole firewall "to make it work".
- Do not store the user password in a shared file.
- Do not run this lab on work or third-party machines without permission.
