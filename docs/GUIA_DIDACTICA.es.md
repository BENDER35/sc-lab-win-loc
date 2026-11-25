# Guía didáctica: laboratorio local de SSH Windows ↔ Linux

## 0. Antes de empezar: ética y ámbito

Este laboratorio está pensado para **aprender en casa, en tu propia red**. Antes de ejecutar cualquier script, cumple estas reglas:

1. Solo usa equipos **de tu propiedad** o para los que tengas **autorización explícita**.
2. Mantén el equipo destino en una red **privada** (casa, aula, laboratorio aislado). Nada de reenvío de puertos desde el router a Internet.
3. Comenta en clase qué haces y por qué. La transversalidad consiste en entender, no en ocultar.
4. Al terminar, **deshaz los cambios** (sección 8). Un buen administrador deja el sistema como lo encontró.

> Este proyecto no evade antivirus, no crea tareas programadas ocultas, no modifica el Registro para arrancar en silencio y no busca credenciales. Si necesitas "entrar" en un equipo ajeno, la respuesta correcta es pedir permiso.

## 1. Material necesario

- Un equipo con **Windows 10/11 o Windows Server** (el "servidor").
- Un equipo con **Linux, macOS o Windows** (el "cliente"), en la misma red.
- Acceso **de administrador** al Windows (para instalar el servicio).
- PowerShell 5.1 o posterior en Windows; Bash en Linux/macOS.
- Opcional: Wireshark para ver el handshake (no verás contraseñas, porque no hay).

## 2. Miniteoría: qué es SSH

SSH (Secure Shell) es un protocolo de **administración remota cifrada**. Sustituye al viejo Telnet, que enviaba todo en texto plano.

Conceptos clave:

| Concepto | Explicación |
|---|---|
| Clave privada | Archivo secreto que guarda el cliente (`lab_ed25519`). Nadie más debe leerlo (`chmod 600`). |
| Clave pública | Archivo que copias al servidor (`lab_ed25519.pub`). Es seguro compartirlo. |
| `authorized_keys` | En Windows, lista de claves públicas autorizadas para un usuario. |
| `sshd` | El servicio servidor de SSH que escucha en el puerto 22. |
| Firewall | Regla que decide desde qué IPs se puede conectar. Aquí la limitamos a tu subred. |
| Ed25519 | Algoritmo de curva elíptica, más corto y seguro que RSA de 1024/2048 bits. |

El cliente demuestra que posee la clave privada; el servidor comprueba la firma con la pública. **La clave privada nunca sale del cliente.**

## 3. Paso 1: generar el par de claves

En tu máquina cliente:

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

Copia `keys/lab_ed25519.pub` al equipo Windows (USB, carpeta compartida, `scp` desde otro equipo autorizado…). **No copies la clave privada.**

## 4. Paso 2: configurar el servidor Windows

En el equipo Windows, abre **PowerShell como Administrador** y sitúate en la carpeta del proyecto:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub
```

El script:

1. Detecta tu IP y máscara y calcula la subred (p. ej. `192.168.1.0/24`).
2. Instala la característica *OpenSSH Server* si falta.
3. Crea el usuario local `labremote` con una contraseña aleatoria (no se usará).
4. Escribe la clave pública en `C:\Users\labremote\.ssh\authorized_keys` y arregla sus permisos ACL.
5. Configura `sshd_config`: `PubkeyAuthentication yes`, `PasswordAuthentication no`, `AllowUsers labremote`.
6. Crea la regla de firewall `SSHD-Lab` **solo para la subred detectada**.
7. Arranca el servicio `sshd` en modo **Manual** (usa `-Autostart` si quieres que arranque con Windows).

Anota la IP que imprime. Ejemplo:

```text
Servidor listo en 192.168.1.50 (subred 192.168.1.0/24)
Usuario: labremote
```

Si quieres que el servicio se inicie automáticamente tras reiniciar (útil en un laboratorio, pero más persistente):

```powershell
.\windows\setup-ssh-server.ps1 -PublicKeyPath .\lab_ed25519.pub -Autostart
```

## 5. Paso 3: conectar desde Linux

```bash
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519
```

Verás la primera vez un aviso de *host key*; es normal, confirma con `yes`. Dentro prueba:

```powershell
whoami
Get-ComputerInfo | Select-Object CsName, WindowsProductName
Get-NetTCPConnection -State Listen | Select-Object -First 5 LocalAddress, LocalPort
exit
```

Ejecutar un único comando sin abrir sesión interactiva:

```bash
./client/connect.sh -H 192.168.1.50 -u labremote -k ./keys/lab_ed25519 -c "whoami"
```

## 6. Paso 4: conectar desde otro Windows

Windows 10/11 ya incluye el cliente OpenSSH. Desde PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\client\connect.ps1 -Host 192.168.1.50 -User labremote -Key .\keys\lab_ed25519
```

Si el equipo es más antiguo, instala *OpenSSH Client* en **Configuración → Aplicaciones → Características opcionales**.

## 7. Verificación y ejercicios propuestos

### Verificación

- `Get-Service sshd` en el servidor debe estar `Running`.
- `Get-NetFirewallRule -Name SSHD-Lab` debe existir y su `RemoteAddress` debe ser tu subred.
- Desde el cliente, `ssh -v ...` muestra `Authentication succeeded (publickey)`.

### Ejercicios

1. **Cambia la clave**: genera otra clave con `KEY_NAME=otra_clave ./scripts/generate-key.sh`, instálala también y comprueba que ambas funcionan.
2. **Rompe la autenticación**: en el servidor, renombra `authorized_keys` y comprueba que la conexión falla. Restáuralo.
3. **Mira el cifrado**: con Wireshark filtra `tcp.port == 22`. Verás paquetes, pero no comandos en claro.
4. **Firewall**: cambia temporalmente `RemoteAddress` a una IP que no sea la tuya y comprueba que ya no puedes entrar. Restaura la regla.
5. **Logs**: revisa `C:\ProgramData\ssh\Logs` (si está activado) o el Visor de eventos.

## 8. Limpieza (muy importante)

En el equipo Windows, como Administrador:

```powershell
.\windows\setup-ssh-server.ps1 -Uninstall
```

Esto detiene el servicio, elimina la regla de firewall, borra el usuario `labremote` y restaura `sshd_config` desde la copia `.lab-bak`. Borra también la carpeta `keys` del cliente si ya no la necesitas.

## 9. Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Connection timed out` | Firewall o IP equivocada | Comprueba `ipconfig` en el servidor y la regla `SSHD-Lab`. |
| `Permission denied (publickey)` | Clave pública mal copiada o ACL incorrecta | Revisa `authorized_keys` y ejecuta de nuevo el script con `-Force`. |
| `sshd` no arranca | Configuración duplicada | Restaura desde `sshd_config.lab-bak` y vuelve a ejecutar. |
| El cliente avisa de IP pública | Estás fuera de la LAN | Detente: este laboratorio no está pensado para Internet. |
| `Set-ExecutionPolicy` bloqueado | Política de la organización | Usa `-Scope Process`, no cambies la política global. |

## 10. Qué NO hacer

- No expongas el puerto 22 a Internet.
- No reutilices la clave privada en varios equipos.
- No desactives el antivirus ni el firewall global para "que funcione".
- No guardes la contraseña del usuario en un archivo compartido.
- No ejecutes este laboratorio en equipos de trabajo o de terceros sin permiso.
