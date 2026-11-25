# Guía didáctica: llaboratoriu llocal de SSH Windows ↔ Linux

## 0. Antes d'empezar: ética y ámbitu

Esti llaboratoriu ta pensáu pa **aprender en casa, na to rede**. Antes d'executar cualquier script, cumple estes regles:

1. Usa namái equipos **de la to propiedá** o pa los que tengas **autorización esplícita**.
2. Ten l'equipu de destín nuna rede **privada** (casa, aula, llaboratoriu aislláu). Nada de reenviar puertos dende'l router a Internet.
3. Cuenta na clase qué fas y por qué. L'oxetivu ye entender, non despintar.
4. Al acabar, **desfai los cambeos** (seición 8). Un bon alministrador dexa'l sistema como lo atopó.

> Esti proyeutu nun evita l'antivirus, nun crea xeres programaes despintaes, nun modifica'l Rexistru pa arrancar en silenciu y nun busca credenciales. Si precisas "entrar" nún equipu ayenu, la respuesta correcta ye pidir permisu.

## 1. Material necesario

- Un equipu con **Windows 10/11 o Windows Server** (el "servidor").
- Un equipu con **Linux, macOS o Windows** (el "cliente"), na mesma rede.
- Accesu **d'alministrador** al Windows (pa instalar el serviciu).
- PowerShell 5.1 o posterior en Windows; Bash en Linux/macOS.
- Opcional: Wireshark pa ver el handshake (nun verás contraseñes, porque nun hai).

## 2. Mini-teoría: qué ye SSH

SSH (Secure Shell) ye un protocolu d'**alministración remota cifrada**. Sustituyó al vieyu Telnet, que mandaba too en testu planu.

| Conceutu | Esplicación |
|---|---|
| Clave privada | Ficheru secretu que guarda'l cliente (`lab_ed25519`). Naide más debe lleelo (`chmod 600`). |
| Clave pública | Ficheru que copies al servidor (`lab_ed25519.pub`). Ye seguru compartilu. |
| `authorized_keys` | En Windows, la llista de claves públiques autorizaes pa un usuariu. |
| `sshd` | El serviciu servidor de SSH que escucha nel puertu 22. |
| Cortexafuegos | Regla que decide dende qué IP se pue coneutar. Equí llindámosla a la to subred. |
| Ed25519 | Algoritmu de curva elíptica, más curtiu y seguru que RSA de 1024/2048 bits. |

El cliente demuestra que tien la clave privada; el servidor comprueba la firma cola pública. **La clave privada nun sale nunca del cliente.**

## 3. Pasu 1: xenerar el par de claves

Nel to equipu cliente:

```bash
git clone https://github.com/BENDER35/sc-lab-win-loc.git
cd sc-lab-win-loc
./scripts/generate-key.sh
```

Salida esperada:

```text
Clave privada: ./keys/lab_ed25519
Clave pública: ./keys/lab_ed25519.pub
```

Copia `keys/lab_ed25519.pub` al equipu Windows (USB, carpeta compartida, `scp` dende otru equipu autorizáu...). **Nun copies la clave privada.**

## 4. Pasu 2: configurar el servidor Windows

Nel equipu Windows, abre **PowerShell como Alministrador** y asítiate na carpeta del proyeutu:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub
```

El script:

1. Detecta la to IP y la máscara y calcula la subred (p. ex. `192.168.1.0/24`).
2. Instala la carauterística *OpenSSH Server* si falta.
3. Crea l'usuariu llocal `labremote` con una contraseña aleatoria (nun s'usará).
4. Escribe la clave pública en `C:\Users\labremote\.ssh\authorized_keys` y arregla los permisos ACL.
5. Configura `sshd_config`: `PubkeyAuthentication yes`, `PasswordAuthentication no`, `AllowUsers labremote`.
6. Crea la regla del cortexafuegos `SSHD-Lab` **namái pa la subred detectada**.
7. Arranca'l serviciu `sshd` en mode **Manual** (usa `-Autostart` si quies que arranque con Windows).

Anota la IP que imprenta. Exemplu:

```text
Servidor llistu en 192.168.1.50 (subred 192.168.1.0/24)
Usuariu: labremote
```

Si quies que'l serviciu arranque automáticamente tres reiniciar:

```powershell
.\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub -Autostart
```

## 5. Pasu 3: coneutar dende Linux

```bash
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519
```

La primer vegada verás un avisu de *host key*; ye normal, responde `yes`. Dientro prueba:

```powershell
whoami
Get-ComputerInfo | Select-Object CsName, WindowsProductName
Get-NetTCPConnection -State Listen | Select-Object -First 5 LocalAddress, LocalPort
exit
```

Executar un solu comandu ensin sesión interactiva:

```bash
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519 -c "whoami"
```

## 6. Pasu 4: coneutar dende otru Windows

Windows 10/11 yá inclúi'l cliente OpenSSH. Dende PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\client\connect.ps1 -Host 192.168.1.50 -User labremote -Key .\keys\lab_ed25519
```

N'equipos más antiguos, instala *OpenSSH Client* en **Configuración → Aplicaciones → Carauterístiques opcionales**.

## 7. Verificación y exercicios propuestos

### Verificación

- `Get-Service sshd` nel servidor ha tar `Running`.
- `Get-NetFirewallRule -Name SSHD-Lab` ha esistir y el so `RemoteAddress` ha ser la to subred.
- Nel cliente, `ssh -v ...` amuesa `Authentication succeeded (publickey)`.

### Exercicios

1. **Cambia la clave**: xenera otra con `KEY_NAME=otra_clave ./scripts/generate-key.sh`, instálala tamién y comprueba que dambes funcionen.
2. **Romp l'autenticación**: renombra `authorized_keys` nel servidor y comprueba que la conexión falla. Restaurala.
3. **Mira'l cifráu**: filtra `tcp.port == 22` en Wireshark. Verás paquetes, pero non comandos en claru.
4. **Cortexafuegos**: cambia temporalmente `RemoteAddress` a una IP que nun seya la toya y comprueba que yá nun pues entrar. Restaura la regla.
5. **Rexistros**: mira `C:\ProgramData\ssh\Logs` (si tá activáu) o'l Visor d'eventos.

## 8. Llimpieza (mui importante)

Nel equipu Windows, como Alministrador:

```powershell
.\windows\setup-ssh-server.ps1 -Uninstall
```

Esto para'l serviciu, elimina la regla del cortexafuegos, borra l'usuariu `labremote` y restaura `sshd_config` dende la copia `.lab-bak`. Borra tamién la carpeta `keys` del cliente si yá nun la precises.

## 9. Solución de problemes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Connection timed out` | Cortexafuegos o IP equivocada | Mira `ipconfig` nel servidor y la regla `SSHD-Lab`. |
| `Permission denied (publickey)` | Clave pública mal copiada o ACL incorrecta | Revisa `authorized_keys` y executa de nuevo con `-Force`. |
| `sshd` nun arranca | Configuración duplicada | Restaura dende `sshd_config.lab-bak` y vuelve a executar. |
| El cliente avisa d'IP pública | Tas fuera de la LAN | Para: esti llaboratoriu nun ye pa Internet. |
| `Set-ExecutionPolicy` bloquiáu | Política de la organización | Usa `-Scope Process`, non camies la política global. |

## 10. Qué NON facer

- Non espongas el puertu 22 a Internet.
- Non reutilices la clave privada en varies máquines.
- Non desactives l'antivirus nin el cortexafuegos completu "pa que funcione".
- Non guardes la contraseña del usuariu nun ficheru compartíu.
- Non executes esti llaboratoriu n'equipos de trabayu o de terceros ensin permisu.
